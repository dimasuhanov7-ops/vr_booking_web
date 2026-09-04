-- Фиксированный порядок клубов в виджете (Effect VR, затем V-Ray).
-- Основная миграция 20260904081507 уже содержит колонку и сид — файл повторяет
-- для совпадения с журналом миграций прод-БД. Операции идемпотентны.

alter table public.booking_clubs
  add column if not exists sort_order int not null default 0;

comment on column public.booking_clubs.sort_order is 'Порядок отображения клубов в виджете (меньше — выше)';

update public.booking_clubs
   set sort_order = case slug
     when 'effect_vr' then 10
     when 'v_ray'     then 20
     else sort_order
   end
 where slug in ('effect_vr', 'v_ray');
