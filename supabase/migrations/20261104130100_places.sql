-- Sprint 4: tempat (places) per Circle. Rujukan: PRD F7, docs/04-data-model.md.
--
-- Tulis HANYA lewat RPC (SECURITY DEFINER, user dari auth.uid()). SELECT untuk anggota Circle.
-- SQLSTATE baru: TH005 = batas tempat per Circle tercapai.
-- (Lainnya dipakai ulang: 28000 tidak login, 22023 argumen tidak valid, 42501 bukan anggota atau
-- bukan pembuat/admin, P0002 tempat tidak ditemukan.)

-- Place spike tanpa Circle tidak berlaku lagi (events.place_id dan member_status.current_place_id
-- menjadi null lewat FK ON DELETE SET NULL).
delete from public.places where circle_id is null;
alter table public.places alter column circle_id set not null;

alter table public.places
  add column created_by uuid references public.profiles (id) on delete set null;

-- Radius: minimal 100 m (PRD F7), maksimal 5000 m. Batas spike 50 diganti.
alter table public.places drop constraint places_radius_m_check;
alter table public.places add constraint places_radius_m_check check (radius_m between 100 and 5000);
alter table public.places add constraint places_name_check check (char_length(name) between 1 and 40);

create index places_circle_idx on public.places (circle_id);

-- RLS: kebijakan spike (semua pengguna boleh baca) diganti anggota Circle. Hak tulis klien: tidak ada.
drop policy places_select_authenticated on public.places;
create policy places_select_member on public.places
  for select to authenticated
  using (public.is_circle_member(circle_id));

-- create_place: setiap anggota Circle boleh (PRD F7). Maksimal 5 tempat per Circle (TH005).
-- Mengembalikan id tempat. Pesan galat tidak memuat koordinat.
create function public.create_place(
  p_circle_id uuid, p_name text, p_lat double precision, p_lng double precision, p_radius_m int)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  -- PRD F7: maksimal 5 tempat per Circle.
  c_max_places constant int := 5;
  v_uid uuid := auth.uid();
  v_name text := btrim(p_name);
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 40 then
    raise exception 'nama tempat harus 1 sampai 40 karakter' using errcode = '22023';
  end if;
  -- NaN lolos "not between" sebagai false pada ekspresi biasa, jadi diperiksa eksplisit.
  if p_lat is null or p_lng is null or p_lat = 'NaN' or p_lng = 'NaN'
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'koordinat tidak valid' using errcode = '22023';
  end if;
  if p_radius_m is null or p_radius_m not between 100 and 5000 then
    raise exception 'radius harus 100 sampai 5000 meter' using errcode = '22023';
  end if;

  -- Kunci baris Circle dulu (urutan kunci sama dengan RPC Circle) agar batas 5 tidak bisa
  -- dilampaui oleh dua pemanggilan bersamaan. Circle tidak ada atau bukan anggota: galat sama.
  perform 1 from public.circles c where c.id = p_circle_id for update;
  if not found or not public.is_circle_member(p_circle_id) then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;
  if (select count(*) from public.places where circle_id = p_circle_id) >= c_max_places then
    raise exception 'batas tempat per circle tercapai' using errcode = 'TH005';
  end if;

  insert into public.places (circle_id, name, center, radius_m, created_by)
  values (p_circle_id, v_name,
          extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography,
          p_radius_m, v_uid)
  returning id into v_id;
  return v_id;
end;
$$;

-- update_place: hanya pembuat atau admin Circle. Nama dan radius wajib diisi (posisi tidak bisa
-- diubah: hapus lalu buat ulang). Tempat tidak ada ATAU pemanggil bukan anggota: P0002 (sama).
create function public.update_place(p_place_id uuid, p_name text, p_radius_m int)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(p_name);
  v_circle uuid;
  v_creator uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 40 then
    raise exception 'nama tempat harus 1 sampai 40 karakter' using errcode = '22023';
  end if;
  if p_radius_m is null or p_radius_m not between 100 and 5000 then
    raise exception 'radius harus 100 sampai 5000 meter' using errcode = '22023';
  end if;

  select p.circle_id into v_circle from public.places p where p.id = p_place_id;
  if found then
    perform 1 from public.circles c where c.id = v_circle for update;
  end if;
  if found then
    select p.created_by into v_creator from public.places p where p.id = p_place_id for update;
  end if;
  if not found or not public.is_circle_member(v_circle) then
    raise exception 'tempat tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_creator is distinct from v_uid and not public.is_circle_admin(v_circle) then
    raise exception 'hanya pembuat atau admin' using errcode = '42501';
  end if;

  update public.places set name = v_name, radius_m = p_radius_m where id = p_place_id;
end;
$$;

-- delete_place: hanya pembuat atau admin Circle. Event lama tetap ada (place_id menjadi null,
-- payload tetap memuat nama tempat); status geofence yang menunjuk tempat ini dikosongkan.
create function public.delete_place(p_place_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_circle uuid;
  v_creator uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;

  select p.circle_id into v_circle from public.places p where p.id = p_place_id;
  if found then
    perform 1 from public.circles c where c.id = v_circle for update;
  end if;
  if found then
    select p.created_by into v_creator from public.places p where p.id = p_place_id for update;
  end if;
  if not found or not public.is_circle_member(v_circle) then
    raise exception 'tempat tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_creator is distinct from v_uid and not public.is_circle_admin(v_circle) then
    raise exception 'hanya pembuat atau admin' using errcode = '42501';
  end if;

  delete from public.places where id = p_place_id;
end;
$$;

revoke all on function
  public.create_place(uuid, text, double precision, double precision, int),
  public.update_place(uuid, text, int), public.delete_place(uuid)
  from public, anon;
grant execute on function
  public.create_place(uuid, text, double precision, double precision, int),
  public.update_place(uuid, text, int), public.delete_place(uuid)
  to authenticated;
