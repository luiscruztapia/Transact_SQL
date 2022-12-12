USE [xxDBxx]
GO
/****** Object:  StoredProcedure [dbo].[VAL_CARGA_P1]     ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- DESCRIPTION:	PARTE 1 DE CARGA SIMULTANEA DEL SERVER_UNO PRODUCCION 
-- =============================================
ALTER PROCEDURE [dbo].[VAL_CARGA_P1    ]
AS

BEGIN 
DECLARE @PARTE INT ,@VAR INT ,@INICIO INT ,@FIN INT ,@VAR1 NVARCHAR(5) ,@SERVIDOR NVARCHAR(25) ,@SERVIDOR2 NVARCHAR(25) ,@CONSULTA NVARCHAR(MAX) ,@TABLA NVARCHAR(75); 

-- PARAMETROS PARA VALIDACION  SIMULTANEA
SET @SERVIDOR = 'SERVER_UNO' SET @PARTE = 1 ; --<---- PARAMETROS A CAMBIAR SERVIDOR A PROCESAR Y NUMERO DE BLOQUE DE TABLAS A EJECUTAR

-- DEFINICION DE INICIO, FIN Y RECORRIDO DEL PROCESO
SELECT @INICIO = INICIO FROM SCL_SP_RANGO WHERE BLOQUE = @PARTE AND SERVIDOR = @SERVIDOR;
SELECT @FIN = FIN FROM SCL_SP_RANGO WHERE BLOQUE = @PARTE AND SERVIDOR = @SERVIDOR;

-- ESTE CURSOR VA A RECORRER EL RANGO DE TABLAS EXTRAIDO 
SET @VAR = @INICIO; -- MARCAMOS DESDE DONDE VA A INICIAR A RECORRER EL CURSOR
WHILE @VAR <= @FIN -- ESTE ES EL RANGO DE INICIO A FIN EN EL QUE VA A EJECUTAR

	BEGIN

		SET @VAR1 = CAST(@VAR AS nvarchar(5))
			
			SET @CONSULTA = CONCAT('SELECT CONCAT(OWNER,''.'',TABLE_NAME) FROM ',@SERVIDOR,' WHERE NUM = ',@VAR1,'')
			DECLARE @T@PARTE TABLE(TABLA NVARCHAR(75))
			INSERT INTO @T@PARTE
			EXEC (@CONSULTA) 
			SELECT @TABLA = TABLA FROM @T@PARTE;

			DECLARE @MONTO NVARCHAR(75),@FECHA NVARCHAR(75)
			-- VALIDA MONTOS
			SELECT @MONTO = 
			CASE 
				WHEN TABLA = 'SISCEL.CO_CARTERA' THEN 'SUM(IMPORTE_DEBE-IMPORTE_HABER)'
				WHEN TABLA = 'SISCEL.CO_CANCELADOS' THEN 'SUM(IMPORTE_HABER)'
				WHEN TABLA = 'SISCEL.CO_PAGOS' THEN 'SUM(IMP_PAGO)'
				WHEN TABLA = 'SISCEL.CO_PAGOSCONC' THEN 'SUM(IMP_CONCEPTO)'
				WHEN TABLA = 'SISCEL.GE_CARGOS' THEN 'SUM(IMP_CARGO)'
				WHEN TABLA = 'SISCEL.FA_HISTDOCU' THEN 'SUM(TOT_FACTURA)'
				WHEN TABLA = 'TOL.TOL_TRAFCIERR_TO_330822' THEN 'SUM(MTO_REAL)'
				WHEN TABLA = 'TOL.TOL_TRAFCIERR_TO_18180722' THEN 'SUM(MTO_REAL)'
				WHEN TABLA = 'TOL.TOL_TRAFCIERR_TO_22220722' THEN 'SUM(MTO_REAL)'
				ELSE '0'
			END 
			FROM @T@PARTE

			-- VALIDA FECHAS 
			SELECT @FECHA = 
			CASE 
				WHEN TABLA = 'SISCEL.GA_ABOCEL' THEN 'MAX(FEC_ALTA)'
				WHEN TABLA = 'SISCEL.GE_CLIENTES' THEN 'MAX(FEC_ALTA)'
				WHEN TABLA = 'SISCEL.CO_CARTERA' THEN 'MAX(FEC_EFECTIVIDAD)'
				WHEN TABLA = 'SISCEL.CO_CANCELADOS' THEN 'MAX(FEC_CANCELACION)'
				WHEN TABLA = 'SISCEL.CO_PAGOS' THEN 'MAX(FEC_EFECTIVIDAD)'
				WHEN TABLA = 'SISCEL.CO_PAGOSCONC' THEN 'MAX(FEC_CANCELACION)'
				WHEN TABLA = 'SISCEL.GE_CARGOS' THEN 'MAX(FEC_ALTA)'
				WHEN TABLA = 'SISCEL.FA_HISTDOCU' THEN 'MAX(FEC_EMISION)'
				WHEN TABLA = 'TOL.TOL_TRAFCIERR_TO_330822' THEN 'MAX(FEC_PROC)'
				WHEN TABLA = 'TOL.TOL_TRAFCIERR_TO_18180722' THEN 'MAX(FEC_PROC)'
				WHEN TABLA = 'TOL.TOL_TRAFCIERR_TO_22220722' THEN 'MAX(FEC_PROC)'
				ELSE 'SYSDATE'
			END 
			FROM @T@PARTE

			SET @CONSULTA = 
			CONCAT('INSERT INTO SCL_VALIDACION_RAO
					SELECT *,GETDATE() CARGA FROM OPENQUERY(',@SERVIDOR,',''
					SELECT /*+ PARALLEL */ 
					''''',@SERVIDOR,''''' SERVER
					,''''',@TABLA,''''' TABLA
					, COUNT(1) CANT
					,',@MONTO,' MONTO
					,',@FECHA,' FECHA 
					FROM ',@TABLA,'
					'');
				') EXEC (@CONSULTA) 

		UPDATE SCL_SP_RANGO SET RECORRIDO = @VAR WHERE BLOQUE = @PARTE AND SERVIDOR = @SERVIDOR;
		SET @VAR = @VAR + 1;
	END

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
	SET @Asunto = 'Carga de Tablas - Validacion RAO'
	SET @Mensaje = CONCAT('
	<! -- mensaje --> 
	<p style=''margin:0cm;margin-bottom:.0001pt;font-size:15px;font-family:"Calibri",sans-serif;''>
	Hola, 
	&nbsp;</p> &nbsp;</p> <! -- espacios --> 
	Finalizó la Parte ',@PARTE,' del proceso de Carga del Servidor ',@SERVIDOR,' para la validación RAO
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