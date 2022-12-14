USE [xxDBxx]
GO
/****** Object:  StoredProcedure [dbo].[VAL_CARGA_SERVIDOR_UNO_DOS]   ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		
-- Create date: 
-- Description:	Script para carga de SERVIDOR_UNO 
-- =============================================
ALTER PROCEDURE [dbo].[VAL_CARGA_SERVIDOR_UNO_DOS] --(@TIP_VALIDA AS NVARCHAR(100)) 
AS

DECLARE @SERVIDOR1 AS NVARCHAR(25),@SERVIDOR2 AS NVARCHAR(25),@CONSULTA AS NVARCHAR(MAX),@TIP_VALIDA AS NVARCHAR(100)

BEGIN
-------------------------------------------------------------
---------- PARAMETROS A MODIFICAR ANTES DE EJECUTAR ---------
-------------------------------------------------------------
SET @SERVIDOR1 = 'SERVIDOR_UNO' SET @SERVIDOR2 = 'SERVIDOR_DOS'; -- COLOCAR SERVIDORES A VALIDAR
SET @TIP_VALIDA = 'ACOTADAS' -- HISTORICAS, PARAMETRICAS o ACOTADAS
-------------------------------------------------------------
-------------------------------------------------------------

-- CREAR TABLAS DE PARA VALIDACION DE SERVIDORES
SET @CONSULTA = 
CONCAT('
IF OBJECT_ID(''MASTER.DBO.',@SERVIDOR1,''') IS NOT NULL DROP TABLE MASTER.DBO.',@SERVIDOR1,'
CREATE TABLE MASTER.DBO.',@SERVIDOR1,'(
	[NUM] [INT] NOT NULL,
	[OWNER] [VARCHAR](25) NOT NULL,
	[TABLE_NAME] [VARCHAR](50) NOT NULL,
	[BLOQUE] [INT] NOT NULL
) ON [PRIMARY]

CREATE UNIQUE INDEX INDICE_FELIZ
ON MASTER.DBO.',@SERVIDOR1,' (NUM);

IF OBJECT_ID(''MASTER.DBO.',@SERVIDOR2,''') IS NOT NULL DROP TABLE MASTER.DBO.',@SERVIDOR2,'
CREATE TABLE MASTER.DBO.',@SERVIDOR2,'(
	[NUM] [INT] NOT NULL,
	[OWNER] [VARCHAR](25) NOT NULL,
	[TABLE_NAME] [VARCHAR](50) NOT NULL,
	[BLOQUE] [INT] NOT NULL
) ON [PRIMARY]

CREATE UNIQUE INDEX INDICE_FELIZ
ON MASTER.DBO.',@SERVIDOR2,' (NUM);
') EXECUTE (@CONSULTA) 

-- LISTA COMPLETA DE TABLAS PARA CONTADOR
SET @CONSULTA = 
CONCAT('
INSERT INTO ',@SERVIDOR1,'
SELECT ROW_NUMBER() OVER(ORDER BY B.BLOQUE) NUM,A.*,B.BLOQUE FROM OPENQUERY(
',@SERVIDOR1,',''
SELECT /*+ PARALLEL */
DISTINCT OWNER,REPLACE(UPPER(TABLE_NAME),''''SISCEL.'''','''''''') TABLE_NAME
FROM SYS.ALL_TABLES
'') A INNER JOIN SCL_',@TIP_VALIDA,' B ON CONCAT(OWNER,''.'',TABLE_NAME) = B.TABLA
ORDER BY B.BLOQUE;

INSERT INTO ',@SERVIDOR2,'
SELECT ROW_NUMBER() OVER(ORDER BY B.BLOQUE) NUM,A.*,B.BLOQUE FROM OPENQUERY(
',@SERVIDOR2,',''
SELECT /*+ PARALLEL */
DISTINCT OWNER,REPLACE(UPPER(TABLE_NAME),''''SISCEL.'''','''''''') TABLE_NAME
FROM SYS.ALL_TABLES
'') A INNER JOIN SCL_',@TIP_VALIDA,' B ON CONCAT(OWNER,''.'',TABLE_NAME) = B.TABLA
ORDER BY B.BLOQUE;
') EXECUTE (@CONSULTA) 

-- LIMPIAR TABLA DE RANGO PARA LA CARGA
DELETE FROM SCL_SP_RANGO;

SET @CONSULTA = 
CONCAT('
INSERT INTO SCL_SP_RANGO
SELECT ''',@SERVIDOR1,''' SERVIDOR,BLOQUE,MIN(NUM) INICIO,MAX(NUM) FIN,MIN(NUM) RECORRIDO,GETDATE() FEC_CARGA FROM ',@SERVIDOR1,'
GROUP BY BLOQUE ORDER BY BLOQUE;

INSERT INTO SCL_SP_RANGO
SELECT ''',@SERVIDOR2,''' SERVIDOR,BLOQUE,MIN(NUM) INICIO,MAX(NUM) FIN,MIN(NUM) RECORRIDO,GETDATE() FEC_CARGA FROM ',@SERVIDOR2,'
GROUP BY BLOQUE ORDER BY BLOQUE;
') EXECUTE (@CONSULTA) 


	BEGIN 
	-- NOTIFICACION POR CORREO CUANDO FINALICE EL PROCESO DE CARGA EN SCL
	DECLARE 
			@CorreosSend varchar(MAX),
			@Asunto nvarchar (255),
			@Mensaje nvarchar(MAX)
			;

	-- DESTINARIOS DEL CORREO
	SET @CorreosSend = 'correo1@test.com;correo2@test.com'
	DECLARE @Firma AS NVARCHAR(MAX) SELECT @Firma = dbo.F_Firma_Correo('firma_remitente')

	SET @Asunto = 'Carga de Tablas - Validacion RAO '+@TIP_VALIDA
	SET @Mensaje = CONCAT('
	<! -- mensaje --> 
	<p style=''margin:0cm;margin-bottom:.0001pt;font-size:15px;font-family:"Calibri",sans-serif;''>
	Hola, 
	&nbsp;</p> &nbsp;</p> <! -- espacios --> 
	Damos inicio a la Validacion de RAO con el conteo de los registros en los servidores ',@SERVIDOR1,' y ',@SERVIDOR2,' para las tablas tipo ',@TIP_VALIDA,'
	&nbsp;</p> &nbsp;</p>',@Firma,'
	')

		BEGIN
			SET NOCOUNT ON;

			EXEC msdb.dbo.sp_send_dbmail
			@profile_name = 'RA', 
			@recipients = @CorreosSend,
			@subject = @Asunto,
			@body = @Mensaje,
			@importance = 'HIGH',
			@body_format ='HTML' --because
		END
	END

END; 