SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Corporativo
-- Create date: 04/12/2025
-- Description:	Libro de Ventas
-- Ejecucuión:
/*
	prueba 5
	declare @hRet varchar(50)='';
	exec corporativo.dbo.Fiscales @hRet out, 'VntLbr', 'DEMO', '20260326', '20260427', '', '', 'FACT', 7963;
	select @hRet; 
*/

-- El Precdimiento Almacenado, valida el libro y retorna un valor numérico si existe una inconsistencia en los datos (@hRtrn)
	-- 1: Diferencias en dis_cen
	-- 2: Salto de número de control
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[Fiscales]
	@hRtrn varchar(50) OUTPUT,
	@hModu char(10) = 'VntLbr',
	@hEmpr char(10)	= 'DEMO',
	@hFec1 date		= '19000101', 
	@hFec2 date		= '20511231',
	@hImpr char(20)	= '',
	@hFact char(20) = '',
	@hTpDc char(6)	= '',
	@hNmro int	= 0,
	@hClie char(10)	= '',
	@hSucu char(6)	= ''
AS
BEGIN
	SET NOCOUNT ON;
	set @hRtrn=''
	declare
	@hCorp varchar(11) = 'Corporativo',
	@hQuery Nvarchar(MAX),
	@hColum Nvarchar(MAX),
	@hWhere Nvarchar(MAX)='(fec_emis between @hFec1 and @hFec2 or (tipo_doc like ''AJ%'' and fcomproban between @hFec1 and @hFec2)) ',
	@hMoned char(6)	= 'USD',
	@hCount int

	if @hImpr<>''
		set @hWhere=@hWhere+'and impfis=@hImpr '
	if @hFact<>''
		set @hWhere=@hWhere+'and impfisfac=@hFact '
	if @hTpDc<>''
		set @hWhere=' tipo_doc=@hTpDc '
	else
		set @hWhere=@hWhere+'and (tipo_doc='+char(39)+'FACT'+char(39)+' or tipo_doc like '+char(39)+'N/%'+char(39)+' or (tipo_doc like '+char(39)+'AJ%'+char(39)+' and campo8<>'+char(39)+char(39)+')) '
	if @hNmro<>0
		set @hWhere=@hWhere+'and nro_doc=@hNmro '
	if @hClie<>''
		set @hWhere=@hWhere+'and co_cli=@hClie '
	if @hSucu<>''
		set @hWhere=@hWhere+'and co_sucu=@hSucu '

--	exec [Corporativo].[dbo].[crpLic] @hEmpr

	if @hModu='VntLbr'
		begin
			create table #temp (fec_emis date, tipo_doc char(4), nro_doc int, co_cli char(10), rif char(18), cli_des varchar(100),
			impfis char(20), numcon char(20), impfisfac char(20), imp_nro_z char(15), co_sucu char(6),
			doc_orig char(4), nro_orig int, fec_orig date, mnt_orig decimal(18,2), impfis_orig char(20), impfisfac_orig char(20),
			monto_bru decimal(18, 2), monto_imp decimal(18, 2), monto_net decimal(18, 2), dis_cen varchar(100),
			nro_che char(15), fec_recp smalldatetime, moneda char(6), tasa decimal(18, 5), ven_ter bit, anulado bit,
			Exento decimal(18, 2), Imp1Ali decimal(18, 2), Imp1Bas decimal(18, 2), Imp1Imp decimal(18, 2),
			Imp2Ali decimal(18, 2), Imp2Bas decimal(18, 2), Imp2Imp decimal(18, 2),
			igtf_base decimal(18, 2), igtf decimal(18, 2))

		set @hColum='case fcomproban when ''19000101'' then fec_emis else fcomproban end fec_emis, tipo_doc, nro_doc, co_cli, impfis, numcon, impfisfac, imp_nro_z, co_sucu, doc_orig, nro_orig, ''19000101'' fec_orig, 0 mnt_orig, monto_bru, monto_imp, monto_net, rtrim(cast(dis_cen as varchar(100))) dis_cen, nro_che, fec_emis fec_recp, moneda, tasa, ven_ter, anulado, '''', '''', case when tipo_doc in(''FACT'',''N/CR'', ''N/DB'') and campo8<>'''' then cast(campo8 as decimal(18,2)) else 0 end igtf_base, otros3 igtf'
		set @hQuery='select '+rtrim(@hColum)+' from '+rtrim(@hEmpr)+'.dbo.docum_cc where '+rtrim(@hWhere)

		insert into #temp(fec_emis, tipo_doc, nro_doc, co_cli,
			impfis, numcon, impfisfac, imp_nro_z, co_sucu,
			doc_orig, nro_orig, fec_orig, mnt_orig,
			monto_bru, monto_imp, monto_net, dis_cen,
			nro_che, fec_recp, moneda, tasa, ven_ter, anulado, impfis_orig, impfisfac_orig, igtf_base, igtf)

		exec sp_executesql @hQuery, N'@hWhere Nvarchar(MAX), @hFec1 date, @hFec2 date, @hImpr char(20), @hFact char(20), @hTpDc char(6), @hNmro int, @hSucu char(6), @hClie char(10)',
		@hWhere, @hFec1, @hFec2, @hImpr, @hFact, @hTpDc, @hNmro, @hSucu, @hClie

		-- Información del cliente
		set @hQuery='update a set rif=b.rif, cli_des=b.cli_des from #temp a inner join '+rtrim(@hEmpr)+'.dbo.clientes b on a.co_cli=b.co_cli and a.co_cli not like ''GEN%'' '
		exec sp_executesql @hQuery

		-- Tasa para operaciones en otra moneda
		set @hQuery='update #temp set tasa='+rtrim(@hEmpr)+'.dbo.crpTasa(@hMoned,fec_emis) where moneda<>@hMoned'
		exec sp_executesql @hQuery, N'@hMoned char(6)', @hMoned

		-- Información fiscal de documentos origen de facturas
		set @hQuery='update a set fec_orig=b.fec_emis, mnt_orig=b.monto_net, impfis_orig=b.impfis, impfisfac_orig=b.impfisfac from #temp a inner join '+rtrim(@hEmpr)+'.dbo.docum_cc b on a.doc_orig=b.tipo_doc and a.nro_orig=b.nro_doc where a.doc_orig=''FACT'' '
		exec sp_executesql @hQuery

		-- Información fiscal de documentos origen de devoluciones
		set @hQuery='with devolucion as (select distinct a.fact_num, b.fec_emis, b.monto_net, b.impfis, b.impfisfac, b.numcon from '+rtrim(@hEmpr)+'.dbo.reng_dvc a inner join '+rtrim(@hEmpr)+'.dbo.docum_cc b on a.num_doc=b.nro_doc where a.tipo_doc=''F'' and b.tipo_doc=''FACT'')
					update a set fec_orig=c.fec_emis, mnt_orig=c.monto_net, impfis_orig=c.impfis, impfisfac_orig=c.impfisfac
					from #temp a inner join devolucion c on a.nro_orig=c.fact_num where a.doc_orig=''DEVO'' '
		exec sp_executesql @hQuery

		-- Información fiscal de documentos origen de cobros NOTAS DE CREDITO (DxPP)
 		set @hQuery='with rengcob as (select a.cob_num, tp_doc_cob, doc_num, dppago_tmp from '+rtrim(@hEmpr)+'.dbo.reng_cob a inner join '+rtrim(@hEmpr)+'.dbo.cobros b on a.cob_num=b.cob_num where b.anulado=0),
						  documcc as (select nro_doc, fec_emis, monto_net, impfis, impfisfac from '+rtrim(@hEmpr)+'.dbo.docum_cc where tipo_doc=''FACT'')
					update a set fec_orig=c.fec_emis, mnt_orig=c.monto_net, impfis_orig=c.impfis, impfisfac_orig=c.impfisfac from #temp a inner join rengcob b on a.nro_orig=b.cob_num and a.tipo_doc=b.tp_doc_cob and a.nro_doc=b.doc_num inner join documcc c on b.dppago_tmp=c.nro_doc where a.doc_orig=''COBR'' and a.tipo_doc=''N/CR'''
		exec sp_executesql @hQuery

		-- Información fiscal de documentos origen de cobros NOTAS DE DEBITO (Diferencial Cambiario)
 		set @hQuery='with rengcob as (select a.cob_num, tp_doc_cob, doc_num from '+rtrim(@hEmpr)+'.dbo.reng_cob a inner join '+rtrim(@hEmpr)+'.dbo.cobros b on a.cob_num=b.cob_num where b.anulado=0),
						  documcc as (select nro_doc, fec_emis, monto_net, impfis, impfisfac from '+rtrim(@hEmpr)+'.dbo.docum_cc where tipo_doc=''FACT'')
					update a set fec_orig=d.fec_emis, mnt_orig=d.monto_net, impfis_orig=d.impfis, impfisfac_orig=d.impfisfac from #temp a inner join rengcob b on a.nro_orig=b.cob_num and a.tipo_doc=b.tp_doc_cob and a.nro_doc=b.doc_num inner join rengcob c on c.tp_doc_cob=''FACT'' and c.cob_num=b.cob_num inner join documcc d on d.nro_doc=c.doc_num where a.doc_orig=''COBR'' and a.tipo_doc=''N/DB'' '
		exec sp_executesql @hQuery

		-- Desglose de impuestos
		set @hQuery='update #temp set Exento='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 0, 0), Imp1Ali='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 1, 1), Imp1Bas='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 1, 2), Imp1Imp='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 1, 3), Imp2Ali='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 2, 1), Imp2Bas='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 2, 2), Imp2Imp='+@hCorp+'.dbo.hLeeDis_cen(dis_cen, 2, 3) where anulado=0'
		exec sp_executesql @hQuery

		/* Validación de datos
		-- Retornos:
		-- 1: Diferencias en dis_cen
		-- 2: Salto de número de control
		-- 3: Número de control duplicado
		-- 4: Número de factura duplicado
		-- 5: Existen FACT, N/CR o N/DB sin datos fiscales
		*/

		-- Se comparan montos contra sumatoria del dis_cen respectivo
		if exists (select fec_emis, tipo_doc, nro_doc, monto_bru, Exento+Imp1Bas+Imp2Bas-igtf montobru_discen, monto_imp, Imp1Imp+Imp2Imp montoimp_discen, monto_net, Exento+Imp1Bas+Imp2Bas+Imp1Imp+Imp2Imp montonet_discen from #temp where tipo_doc in('FACT','N/CR') and (monto_bru<>Exento+Imp1Bas+Imp2Bas-igtf or monto_imp<>Imp1Imp+Imp2Imp or monto_net<>Exento+Imp1Bas+Imp2Bas+Imp1Imp+Imp2Imp)) begin
			set @hQuery='select dis_cen, igtf, fec_emis, tipo_doc, nro_doc, monto_bru, Exento+Imp1Bas+Imp2Bas-igtf montobru_discen, monto_imp, Imp1Imp+Imp2Imp montoimp_discen, monto_net, Exento+Imp1Bas+Imp2Bas+Imp1Imp+Imp2Imp montonet_discen from #temp where tipo_doc in(''FACT'',''N/CR'') and (monto_bru<>Exento+Imp1Bas+Imp2Bas-igtf or monto_imp<>Imp1Imp+Imp2Imp or monto_net<>Exento+Imp1Bas+Imp2Bas+Imp1Imp+Imp2Imp) order by 1'
			exec sp_executesql @hQuery
			set @hRtrn='Diferencias en dis_cen'
			return
		end

		-- Cuando el proceso es llamado por el SP Smart, se llena #tmpSmart y termina el SP
		-- Henry: coloca las validaciones para Smart, antes de este corte

		if OBJECT_ID('tempdb..#tmpSmart') IS NOT NULL BEGIN
			insert into #tmpSmart
			select * from #temp where tipo_doc in('FACT', 'N/CR', 'N/DB') and numcon='' and anulado=0;
			return
		END

		-- No se validan los correlativos si filtran por tipo de documento
		if @hTpDc='' begin
			-- Se revisa que el número de control anterior exista tanto en facturas como devoluciones
			-- Se segmentan los bloques de datos por la serie (Primer caracter de impfisfac)

			with x as (select left(impfisfac,1) serie, cast(replace(numcon,'-','') as int)-1 Ctrl_flnt, tipo_doc, nro_doc, replace(numcon,'-','') numcon, lag(cast(replace(numcon,'-','') as int))
						over (partition by impfis, left(impfisfac,1) order by replace(numcon,'-','')) AS IdAnterior
						from #temp where tipo_doc in ('FACT','N/CR','N/DB'))
						select top 1 @hCount=1 from x where IdAnterior IS NOT NULL AND cast(numcon as int) <> IdAnterior+1 order by serie, numcon;

			if @hCount>0 and 1=0 begin
				set @hQuery='with x as (select left(impfisfac,1) serie, cast(replace(numcon,''-'','''') as int)-1 Ctrl_flnt, tipo_doc, nro_doc, replace(numcon,''-'','''') numcon, lag(cast(replace(numcon,''-'','''') as int))
						over (partition by impfis, left(impfisfac,1) order by replace(numcon,''-'','''')) AS IdAnterior
						from #temp where tipo_doc in (''FACT'',''N/CR'',''N/DB''))
						select serie, ctrl_flnt, tipo_doc, nro_doc, numcon from x where IdAnterior IS NOT NULL AND cast(numcon as int) <> IdAnterior+1 order by serie, numcon;'
				exec sp_executesql @hQuery
				set @hRtrn='Salto de número de control'
				return
			end
		end

		-- Se revisa que el número de control no se repita
		if exists (select 1 from #temp where numcon<>'' group by numcon having count(numcon)>1) begin
			set @hQuery='with repetidas as (select numcon, count(numcon) repite from #temp where numcon<>'''' group by numcon having count(numcon)>1)
						select a.fec_emis, a.tipo_doc, a.nro_doc, a.impfis, a.numcon, a.impfisfac from #temp a inner join repetidas b on a.numcon=b.numcon'
			exec sp_executesql @hQuery
			set @hRtrn='Número de control duplicado'
			return
		end

		-- Se revisa que el número de factura no se repita
		if exists (select 1 from #temp where impfisfac<>'' group by tipo_doc, impfisfac having count(impfisfac)>1) begin
			set @hQuery='with x as (select impfisfac, count(impfisfac) repite from #temp where impfisfac<>'''' group by tipo_doc, impfisfac having count(impfisfac)>1)
						select a.fec_emis, a.tipo_doc, a.nro_doc, a.impfis, a.numcon, a.impfisfac from #temp a inner join x on a.impfisfac=x.impfisfac'
			exec sp_executesql @hQuery
			set @hRtrn='Número de factura duplicado'
			return
		end

		-- Se revisa que las FACT, N/CR o N/DB tengan datos fiscales
		if exists (select 1 from #temp where (tipo_doc='FACT' and (impfis='' or numcon='' or impfisfac='' or imp_nro_z='')) or (tipo_doc in('N/CR','N/DB') and (impfis='' or numcon='' or impfisfac='' or imp_nro_z='' or impfis_orig='' or impfisfac_orig=''''))) begin
			set @hQuery='select fec_emis, tipo_doc, nro_doc, impfis, numcon, impfisfac, imp_nro_z, impfis_orig, impfisfac_orig from #temp where (tipo_doc=''FACT'' and (impfis='''' or numcon='''' or impfisfac='''' or imp_nro_z='''')) or (tipo_doc in(''N/CR'',''N/DB'') and (impfis='''' or numcon='''' or impfisfac='''' or imp_nro_z='''' or impfis_orig='''' or impfisfac_orig='''')) order by 1'
			exec sp_executesql @hQuery
			set @hRtrn='Existen FACT, N/CR o N/DB sin datos fiscales'
			return
		end

		/* FIN Validación de datos */

		-- Valores negativos
		set @hQuery='update #temp set monto_bru=monto_bru*-1, monto_imp=monto_imp*-1, monto_net=monto_net*-1, Exento=Exento*-1, Imp1Ali=Imp1Ali*-1, Imp1Bas=Imp1Bas*-1, Imp1Imp=Imp1Imp*-1, Imp2Ali=Imp2Ali*-1, Imp2Bas=Imp2Bas*-1, Imp2Imp=Imp2Imp*-1, igtf_base=igtf_base*-1, igtf=igtf*-1 where tipo_doc in(''N/CR'', ''AJPM'')'
		exec sp_executesql @hQuery

		-- Documentos anulados
		set @hQuery='update #temp set rif='''', cli_des=''** ANULADA **'', monto_bru=0, monto_imp=0, monto_net=0, Exento=0, Imp1Ali=0, Imp1Bas=0, Imp1Imp=0, Imp2Ali=0, Imp2Bas=0, Imp2Imp=0, igtf_base=0, igtf=0 where anulado=1'
		exec sp_executesql @hQuery

		-- Se eliminan documentos anulados
		set @hQuery='delete #temp where anulado=1 and tipo_doc not in (''FACT'',''N/CR'',''N/DB'')'
		exec sp_executesql @hQuery

		-- Reportes Z en 0
		set @hQuery='update #temp set rif='''', cli_des=''SIN OPERACIONES'', impfisfac='''' WHERE impfisfac=''ZETAEN0'''
		exec sp_executesql @hQuery

		select * from #temp
	end

	if @hModu='TxtSnt'
		begin
			set @hQuery='select str(CONCAT(YEAR(d.fec_emis), FORMAT(d.fec_emis, ''MM''))) perImp, cast(a.fcomproban as date) docFch, ''C'' oprTip, case d.doc_orig when ''FACT'' then ''01'' when ''N/DB'' then ''02'' when ''N/CR'' then ''03'' end docTip, replace(p.rif, ''-'', '''') prvRif,'+
			'a.nro_fact fscFct, a.n_control fscCtr, a.monto_bru-a.monto_des+a.monto_rec+a.monto_otr-a.otros3+a.monto_imp docTtl, a.monto_bru-a.monto_des+a.monto_rec+a.monto_otr-'+@hCorp+'.dbo.hLeeDis_cen(a.dis_cen, 0, 0) docBas, round(d.monto_net,2) ivaRet, isnull(case a.doc_orig when ''DEVO'' then v.nro_fact else o.nro_fact end,0) fctOrg, cast(CONCAT(YEAR(d.fec_emis), FORMAT(d.fec_emis, ''MM''), d.nro_che) as varchar(14)) cmpRet, '+@hCorp+'.dbo.hLeeDis_cen(a.dis_cen, 0, 0)-a.otros3 mntExe, 16.00 pctIva, ''0'' expImp '+
			'from '+rtrim(@hEmpr)+'.dbo.docum_cp d '+																			-- Documento
			'inner join '+rtrim(@hEmpr)+'.dbo.prov p on p.co_prov=d.co_cli '+													-- Proveedor del documento (ficha)
			'left join '+rtrim(@hEmpr)+'.dbo.docum_cp a on a.tipo_doc=d.doc_orig and a.nro_doc=d.nro_orig '+					-- documento Asociados
			'left join '+rtrim(@hEmpr)+'.dbo.docum_cp o on o.tipo_doc=a.doc_orig and o.nro_doc=a.nro_orig '+					-- documento Origen de N/CR y N/DB
			'left join '+rtrim(@hEmpr)+'.dbo.reng_dvp r on a.doc_orig=''DEVO'' and r.tipo_doc=''C'' and r.fact_num=a.nro_orig '+ -- Compra Origen de Devolución 1
			'left join '+rtrim(@hEmpr)+'.dbo.docum_cp v on v.tipo_doc=''FACT'' and v.nro_doc=r.num_doc '						-- Compra Origen de Devolución 2
			set @hWhere='where d.anulado=0 and d.tipo_doc like '+char(39)+'AJ%'+char(39)+' and d.campo8<>'+char(39)+char(39)+' and d.fec_emis between @hFec1 and @hFec2 order by 12'
			set @hQuery=@hQuery+@hWhere
			print @hQuery
			exec sp_executesql @hQuery, N'@hTpDc char(6), @hNmro int, @hSucu char(6), @hFec1 date, @hFec2 date, @hClie char(10)',
				@hTpDc, @hNmro, @hSucu, @hFec1, @hFec2, @hClie
		end

	if @hModu='CRP' begin
		print 'Ver 1.0
		
Valores de los parámetros recibidos:
	@hRtrn varchar(50) OUTPUT,
	@hModu char(10) = '+@hModu+',
	@hEmpr char(10)	= '+@hEmpr+',
	@hFec1 date		= '+cast(@hFec1 as char(10))+', 
	@hFec2 date		= '+cast(@hFec2 as char(10))+',
	@hImpr char(20)	= '',
	@hFact char(20) = '',
	@hTpDc char(6)	= '+@hTpDc+',
	@hNmro int		= '+cast(@hNmro as char(10))+',
	@hClie char(10)	= '+@hClie+',
	@hSucu char(6)	= '+@hSucu+'

Ejecución:
	declare @hRet varchar(50)='';
	exec corporativo.dbo.Fiscales @hRet out, ''VntLbr'', ''DEMO'', ''20260301'', ''20260314'';
	select @hRet;

Retorna: (Valor entero)
	1: Diferencias en dis_cen
	2: Salto de número de control
	3: Número de control duplicado
	4: Número de factura duplicado
	5: Existen FACT, N/CR o N/DB sin datos fiscales

Módulos:
	Ventas:
		VntLbr: Libro de Ventas

	Compras:
		TxtSnt: Txt para el seniat (Relación de retenciones de IVA para el portal)
	'end
END
GO
