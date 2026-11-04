-- Sprint 1 (T1.6): profil pengguna dan trigger pembuatan profil.
-- Rujukan: docs/04-data-model.md. Kebijakan "lihat profil anggota Circle yang sama" ditambah
-- di migrasi Circle (tabel circle_members belum ada di sini).

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  color text not null default '#0F766E' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  -- ASUMSI: batas 2048 karakter agar klien tidak menyimpan teks sembarang panjang.
  avatar_url text check (char_length(avatar_url) <= 2048),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.profiles enable row level security;

-- Bawaan Supabase memberi ALL ke anon dan authenticated: cabut dulu, beri hanya yang perlu.
revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;
-- UPDATE per kolom: id, created_at, deleted_at tidak bisa diubah klien. Tidak ada INSERT/DELETE.
grant update (display_name, color, avatar_url) on public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Trigger: profil otomatis untuk setiap pengguna baru (termasuk anonim)
-- ---------------------------------------------------------------------------
-- Tidak boleh gagal: galat di sini akan menggagalkan pendaftaran. Nama kosong, hanya spasi,
-- atau lebih dari 40 karakter diganti 'Pengguna'.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(new.raw_user_meta_data ->> 'display_name');
begin
  if v_name is null or char_length(v_name) not between 1 and 40 then
    v_name := 'Pengguna';
  end if;
  insert into public.profiles (id, display_name) values (new.id, v_name)
  on conflict (id) do nothing;
  return null;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Pengguna yang sudah ada sebelum migrasi ini (mis. dari spike) ikut dibuatkan profil.
insert into public.profiles (id, display_name)
select u.id,
       case when char_length(btrim(u.raw_user_meta_data ->> 'display_name')) between 1 and 40
            then btrim(u.raw_user_meta_data ->> 'display_name')
            else 'Pengguna' end
from auth.users u
on conflict (id) do nothing;
