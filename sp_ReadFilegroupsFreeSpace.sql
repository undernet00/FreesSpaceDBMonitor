USE [DBTools]
GO
 
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Martín Rivero
-- Create date: 29/03/2020
-- Description:	Stores used space information on
--              deployed SQL Server Express 
--              databases.
-- =============================================
ALTER PROCEDURE [mon].[sp_ReadFilegroupsFreeSpace]
	-- EXEC sp_ReadFilegroupsFreeSpace
AS
BEGIN
	SET NOCOUNT ON;

	SELECT *
	INTO #Bases
	FROM DBTools.mon.Bases
	WHERE Activa = 'S'

	DECLARE @IdBase INT
	DECLARE @Ruta VARCHAR(1024)
	DECLARE @NombreBase VARCHAR(256)
	DECLARE @SQL VARCHAR(MAX)

	WHILE (
			SELECT COUNT(*)
			FROM #Bases
			) > 0
	BEGIN
		SELECT TOP 1 @IdBase = IdBase
			,@Ruta = Ruta
			,@NombreBase = Nombre
		FROM #Bases

		--Prepara el comando SQL
		/*
		*TamañoEnKB* es el total de espacio utilizado por datos e índices en el filegroup. Es el ocupado real y el que se usará para restarle al máximo de 10gb de MSSQL Express.
		*LibreEnKB* es el espacio libre que hay en el espacio reservado. El reservado puede ser menor o igual que el máximo posible de SQL Server Express.
		            No necesariamente es el libre que más nos interesa. Ya que la reserva puede aumentar hasta el máximo de SQL Server Express.
		*ReservadoenKB* es el tamaño del file group. Que puede ser mayor o igual al total de datos que contiene el FG.
		*/
		SET @SQL = 'SELECT * FROM OPENQUERY( ' + @Ruta + ',''SET FMTONLY OFF; EXEC(''''USE ' + @NombreBase + ';  SELECT
					''''''''' + CAST(@IdBase AS VARCHAR) + ''''''''' as IdBase,
					[name] AS FileName,
					CAST(FILEPROPERTY(name,''''''''SpaceUsed'''''''')AS INT)*8.0 AS TamañoEnKB,
					size*8.0 -CAST(FILEPROPERTY(name,''''''''SpaceUsed'''''''')AS INT)*8.0 AS LibreEnKB,
					size*8.0 AS ReservadoEnKB,
					type_desc Tipo,
					GETDATE() Fecha
					FROM ' + @NombreBase + '.sys.database_files'''')'')'

		BEGIN TRY
			INSERT INTO DBTools.mon.Espaciofilegroups
			EXEC (@SQL)
				--SELECT @SQL
		END TRY

		BEGIN CATCH
			INSERT INTO DBTools.mon.LogMonitoreo (
				SQL
				,Mensaje
				,ErrorNumero
				,Fecha
				,InvocadoDesde
				,Error
				)
			VALUES (
				@SQL
				,ERROR_MESSAGE()
				,ERROR_NUMBER()
				,GETDATE()
				,(
					SELECT OBJECT_NAME(@@PROCID)
					)
				,'S'
				)
		END CATCH

		DELETE #Bases
		WHERE IdBase = @IdBase
	END

	DROP TABLE #Bases
END
