update public.booking_stations s
set row_index       = (substring(s.label from 2)::int - 1) / 6,
    position_in_row = (substring(s.label from 2)::int - 1) % 6
from public.booking_rooms r
join public.booking_clubs c on c.id = r.club_id
where s.room_id = r.id
  and c.slug = 'v_ray'
  and r.name = 'Большой зал'
  and s.type = 'vr_headset'
  and s.label ~ '^#[0-9]+$';
