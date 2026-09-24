update public.booking_clubs
set timezone = 'Asia/Yekaterinburg'
where timezone = 'Europe/Moscow';

alter table public.booking_clubs
  alter column timezone set default 'Asia/Yekaterinburg';
