select *
from
(select distinct
ag.code ,
ag.name ,
rpt.period_begin,
rpt.period_end,
tct.doc_no,
sgm.cpn_no,
sgm.carrier,
sgm.flight,
trunc(sgm.departure_time) flt_date,
sgm.service_class,
fb.farebasis,
decode(tct.nds,'ÄÀ','ÂÂË','ÍÅÒ','ÌÂË',tct.nds) nds,
rpt.rpt_currency,
sgm.val_amount tarif_cpn_cur,
sgm.val_amount*tr.nat_curr_rate tarif_cpn_rub,

    (select sum(nvl(mt.trans_amount,0)*tr.nat_curr_rate)
    from s7.scs_tvm_rate_mt mt
    where sgm.doc_id=mt.doc_id (+)and
          sgm.cpn_no=mt.cpn_no (+))as Tax_top_rub,

    (select sum(nvl(mt.trans_amount,0)*tr.nat_curr_rate)
    from s7.scs_tvm_rate_at mt
    where sgm.doc_id=mt.doc_id (+)and
          sgm.cpn_no=mt.cpn_no (+))as Tax_air_rub,

ap.passport||' '||ap.home_address||' '||ap.birthday as dop_info,

       nvl((select max(td.pnr_reference)
          from s7.tdb_doc          td
          where td.doc_no = tct.doc_no and
                td.doc_kind in ('TCT') and
                td.issue_date = tct.issue_date),
                (select case when instr(tct1.pnr,'/')!=0 then
                 substr(tct1.pnr,instr(tct1.pnr,'/')+1)
                 else tct1.pnr end
                 from s7.scs_tct tct1
                 where
                 tct1.doc_id=tct.first_conjunction)) pnr_reference,
case when tct.ifexcng='ÄÀ' or
          exists (select 1
                 from
                 s7.scs_fop fop
                 where
                 fop.trns_id=tr.trns_id and
                 fop.fop_type_code='EX')
      then 'EX'
      else null end as ifexc,
(select listagg(fop.fop_type_code,'/') within group (order by fop.fop_no)
         from s7.scs_fop fop
         where fop.trns_id=tr.trns_id) "ÔÎÏ"

from
      s7.scs_rpt rpt,
      s7.scs_btch b,
      s7.scs_batch_trns bt,
      s7.scs_trans tr,
      s7.scs_tct tct,
      s7.scs_tct_sgm sgm,
      s7.dic_agency ag,
      s7.dic_farebasis fb,
      s7.scs_pass_add_info ap
where
      tct.issue_date between $P{D_from} and $P{D_to} and
      trunc(sgm.departure_time) between $P{D2_from} and $P{D2_to} and --trunc(sgm.departure_time) >= '01.12.2014' and
      rpt.rpt_id=b.rpt_id and
      b.rpt_id=bt.rpt_id and
      b.btch_no=bt.btch_no and
      bt.trns_id=tr.trns_id and
      tr.trns_id=tct.trns_id and
      tr.trns_kind in ('S') and
      tct.doc_id=sgm.doc_id and
      sgm.carrier in ('S7','C7','Ñ7') and
      sgm.fare_basis=fb.id(+) and
      tct.doc_type in ('TCT')and --EBT
      tct.doc_id=ap.doc_id(+) and
      rpt.agency_id=ag.id and
      sgm.service_class in ('K','M','L','V','T','R','A','S','N','Q','O','W') and --ñïèñîê èçìåíåí 28 04 2015 ïî ïðîñüáå ÀÈ Ìèí÷îíîê

(select max(tct.doc_id+sgm.cpn_no)
from
s7.scs_tct tct1,
s7.scs_tct_sgm sgm
where
tct1.first_conjunction=tct.first_conjunction and
tct1.doc_id=sgm.doc_id and
sgm.carrier is not null
)  =  tct.doc_id+sgm.cpn_no and

     not exists (select 1 
     from
     s7.scs_trans tr1,
     s7.scs_tct tct1,
     s7.scs_tct_sgm sgm1
     where
     tr1.trns_id=tct1.trns_id and
     tct1.doc_id=sgm1.doc_id and
     sgm1.carrier is not null and
     tr1.trns_kind in ('R') and
     tct1.doc_no=tct.doc_no and
     sgm1.cpn_no=sgm.cpn_no and
     tct1.issue_date between $P{D_from} and add_months($P{D_to},12)
     ) and

    not exists (select 1
       from 
       s7.flt_flight flt,
       s7.flt_batch b,
       s7.flt_pax_doc pd
       where
       flt.id=b.flight_id and
       b.id=pd.batch_id and
       pd.serial_no = tct.doc_no and
       pd.coupon_no = sgm.cpn_no and
       flt.flight_date>=$P{D_from}

       union

       select 1 
       from
       s7.flt_flight flt,
       s7.flt_batch b,
       s7.flt_ch_batch chb,
       S7.FLT_ch_PAX_DOC d
       where
       flt.id=b.flight_id and
       b.id=chb.id and
       b.ID=d.BATCH_ID and
       d.serial_no = tct.doc_no and
       d.coupon_no = sgm.cpn_no and
       flt.flight_date>=$P{D_from}
      )) osn
where

not exists
(select 1
from
s7.scs_trans tr1,
s7.scs_fop fop
where
tr1.trns_id=fop.trns_id and
tr1.trns_date_time>=$P{D_from} and
fop.fop_type_code='EX' and
fop.fop_doc=osn.doc_no and
osn.cpn_no in (decode(substr(fop.cpns,1,1),'R',1),decode(substr(fop.cpns,2,1),'R',2),decode(substr(fop.cpns,3,1),'R',3),decode(substr(fop.cpns,4,1),'R',4))
)
