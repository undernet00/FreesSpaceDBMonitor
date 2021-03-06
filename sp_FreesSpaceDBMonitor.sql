USE [DBTools]
GO
 
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =====================================================================
-- Author:		Martin Rivero
-- Create date: 05/04/2020
-- Description:	Sends an email with free and 
--				used space information on SQL Server Express databases.
--              
--              SQL Server Express has a 10gb file limit per file. 
-- =====================================================================
ALTER PROCEDURE [mon].[sp_FreesSpaceDBMonitor]
AS
BEGIN
	SET NOCOUNT ON;

	--Este script no tiene en cuenta bases de datos con capacidad de crecimiento ilimitada (ej: SQL Server no Express).
	SELECT b.Lugar
		,b.Nombre NombreDB
		,CAST(fg.TamañoEnKB / 1024 AS NUMERIC(18, 2)) TamañoEnMB
		--,FORMAT( (fg.TamañoEnKB-fg.LibreEnKB)/1024*100/v.TamañoMaximoMB ,'N2') Porcentaje
		,CAST(fg.TamañoEnKB / 1024 * 100 / v.TamañoMaximoMB AS NUMERIC(18, 2)) Porcentaje
		,fg.Tipo TipoFG
		,fg.Fecha UltimaLectura
	INTO #FileGroups
	FROM DBTools.mon.EspacioFilegroups fg
	INNER JOIN (
		SELECT IdBase
			,Nombre
			,MAX(Fecha) UltimaFecha
		FROM DBTools.mon.EspacioFilegroups
		GROUP BY IdBase
			,Nombre
		) UltimasFechas ON fg.IdBase = UltimasFechas.IdBase
		AND fg.Nombre = UltimasFechas.Nombre
		AND fg.Fecha = UltimasFechas.UltimaFecha
	INNER JOIN DBTools.mon.Bases b ON fg.IdBase = b.IdBase
	INNER JOIN DBTools.mon.Versiones v ON b.IdVersion = v.IdVersion
	WHERE v.EsExpress = 'S'
		AND fg.Tipo = 'ROWS'
		AND b.Activa = 'S'

	--SELECT * FROM #FileGroups ORDER BY Porcentaje DESC
	--TODO: Sólo usar las variables necesarias
	DECLARE @IdBase INT
	DECLARE @Nombre VARCHAR(256)
	DECLARE @Body1 VARCHAR(MAX)
	DECLARE @Asunto NVARCHAR(MAX)
	DECLARE @Version INT

	SET @Body1 = '<P align="center" style="font-family: Lucida Console, Monaco, monospace;font-size: 2.50em;" >ESPACIO UTILIZADO EN BASES DE SUCURSALES</P>'
	SET @body1 = @body1 + '<table align="center" cellpadding="15" cellspacing="0" style="color: #666666; border-radius: 5px; letter-spacing: 1.50px;
							text-align:center; border: 1px solid lightgrey; font-family: Lucida Console, Monaco, monospace;">' + '<tr style="font-size: 0.90em">
							<th style=" background-color: #d9d9d9;">Sucursal</th>
							<th style=" background-color: #d9d9d9;">Base</th>
							<th style=" background-color: #d9d9d9;">Tamaño</th>
							<th style=" background-color: #d9d9d9;">Espacio Ocupado</th>					
							<th style=" background-color: #d9d9d9;">Tipo</th>					
							<th style=" background-color: #d9d9d9;">Última Lectura</th>					
							</tr>'

	SELECT @body1 = @body1 + '<tr style="font-size: 1.00em;">' + '<td style=" background-color: #cccccc; border-bottom: 1px solid #BDBDBD; color: white;">' + fg.Lugar + '</td>' + '<td style=" background-color: #e6e6e6; text-align: left; border-bottom: 1px solid #d9d9d9;">' + fg.NombreDB + '</td>' + '<td style=" background-color: #e6e6e6; text-align: left; border-bottom: 1px solid #d9d9d9;">' + CAST(fg.TamañoEnMB AS VARCHAR) + ' MB </td>' + CASE 
			WHEN (fg.Porcentaje >= '90') --rojo
				THEN '<td style=" background-color: #EF5350; padding-left: 30px; color: white;">' + CAST(fg.Porcentaje AS VARCHAR(8)) + ' %</td>'
			WHEN (
					fg.Porcentaje >= '75'
					AND fg.Porcentaje < '90'
					) --amarillo
				THEN '<td style=" background-color: #E3D545; padding-left: 30px; color: white;">' + CAST(fg.Porcentaje AS VARCHAR(8)) + ' %</td>'
			WHEN (fg.Porcentaje < '75') --verde
				THEN '<td style=" background-color: #81c784; padding-left: 30px; color: white;">' + CAST(fg.Porcentaje AS VARCHAR(8)) + ' %</td>'
			END + '<td style=" background-color: #e6e6e6; text-align: center; border-bottom: 1px solid #d9d9d9;">' + fg.TipoFG + '</td>' + CASE 
			WHEN DATEDIFF(hh, fg.UltimaLectura, getdate()) < 36 --lectura hecha en menos de 36 horas 
				THEN '<td style=" background-color: #e6e6e6; text-align: left; border-bottom: 1px solid #d9d9d9;">' + CAST(fg.UltimaLectura AS VARCHAR) + '</td>'
			ELSE '<td style=" background-color: #e6e6e6; text-align: left; border-bottom: 1px solid #d9d9d9;color: #EF5350">' + CAST(fg.UltimaLectura AS VARCHAR) + '</td>'
			END
	FROM #FileGroups fg
	ORDER BY fg.Porcentaje DESC

	SELECT @body1 = @body1 + '</table>'

	SET @Asunto = 'Espacio Ocupado en Bases de Sucursales'

	--SELECT @Body1
	EXEC msdb.dbo.sp_send_dbmail @Profile_name = 'Mosca'
		,@Body = @body1
		,@Body_format = 'HTML'
		,@Recipients = 'xxx@xxxx.com.uy'
		,
		--@blind_copy_recipients	= 'xxx@xxxxx.com.uy',
		@Subject = @Asunto

	DROP TABLE #FileGroups
END