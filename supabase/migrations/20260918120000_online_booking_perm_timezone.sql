-- Клубы находятся в Перми: Asia/Yekaterinburg, UTC+5 без летнего времени.
--
-- Сид (20260904081507) ошибочно поставил Europe/Moscow. Все серверные функции
-- (booking_busy_intervals, booking_create_order, booking_station_price) берут
-- пояс из booking_clubs.timezone, так что одной правки данных достаточно:
-- «13:00» в виджете теперь означает 13:00 по Перми, а не по Москве.

update public.booking_clubs
set timezone = 'Asia/Yekaterinburg'
where timezone = 'Europe/Moscow';

alter table public.booking_clubs
  alter column timezone set default 'Asia/Yekaterinburg';
