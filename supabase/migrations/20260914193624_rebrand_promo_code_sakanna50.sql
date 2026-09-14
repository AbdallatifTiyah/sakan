update promo_codes set code = 'SAKANNA50'
where code = 'MAWDI50'
  and not exists (select 1 from promo_codes where code = 'SAKANNA50');
