-- Sprint 0A: RPC upload_points (identitas, idempotensi, validasi).
begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'a@example.test'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'b@example.test');

-- Pembantu: satu objek titik; mins = menit lalu.
create function pg_temp.pt(lat double precision, lng double precision, mins numeric)
returns jsonb language sql as $$
  select jsonb_build_object('lat', lat, 'lng', lng, 'accuracy_m', 10, 'speed_mps', 0,
    'battery_pct', 80, 'is_moving', false, 'recorded_at', now() - mins * interval '1 minute')
$$;

-- Pembantu: panggil upload_points, kembalikan 'ok' atau pesan error (untuk memeriksa isi pesan).
create function pg_temp.try_upload(p jsonb) returns text language plpgsql as $$
begin
  perform public.upload_points(p);
  return 'ok';
exception when others then
  return sqlerrm;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

-- (3) user_id palsu di payload diabaikan
select is(
  public.upload_points(jsonb_build_array(
    pg_temp.pt(-6.2, 106.8167, 5) || '{"user_id":"bbbbbbbb-0000-0000-0000-00000000000b"}'::jsonb)),
  1, 'upload_points memasukkan 1 titik walau payload memuat user_id palsu');

reset role;
select is((select count(*)::int from public.location_points where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'),
  1, 'titik tersimpan atas nama auth.uid() (A)');
select is((select count(*)::int from public.location_points where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'),
  0, 'tidak ada titik atas nama user_id palsu (B)');
select is((select extensions.ST_X(point::extensions.geometry)::text || ',' || extensions.ST_Y(point::extensions.geometry)::text
           from public.location_points where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'),
  '106.8167,-6.2', 'urutan lng,lat benar pada geography');

set local role authenticated;

-- (4) idempoten
select is(public.upload_points(jsonb_build_array(
    pg_temp.pt(-6.2, 106.8167, 10), pg_temp.pt(-6.2, 106.8167, 11), pg_temp.pt(-6.2, 106.8167, 12))),
  3, 'batch pertama: 3 baris masuk');
select is(public.upload_points(jsonb_build_array(
    pg_temp.pt(-6.2, 106.8167, 10), pg_temp.pt(-6.2, 106.8167, 11), pg_temp.pt(-6.2, 106.8167, 12))),
  0, 'batch yang sama dikirim ulang: sukses, 0 baris baru');
select is((select count(*)::int from public.location_points), 4, 'baris tidak ganda (1 + 3)');
select is(public.upload_points(jsonb_build_array(
    pg_temp.pt(-6.2, 106.8167, 10), pg_temp.pt(-6.2, 106.8167, 11), pg_temp.pt(-6.2, 106.8167, 13))),
  1, 'batch tumpang tindih: hanya 1 baris baru dihitung');
select is((select count(*)::int from public.location_points), 5, 'total 5 baris setelah tumpang tindih');

-- (5) validasi
select throws_ok($$select public.upload_points('[]'::jsonb)$$, '22023', null::text, 'array kosong ditolak');
select throws_ok($$select public.upload_points((
  select jsonb_agg(jsonb_build_object('lat', 0, 'lng', 0, 'recorded_at', now() - g * interval '1 second'))
  from generate_series(1, 501) g))$$, '22023', null::text, '501 elemen ditolak');
select throws_ok($$select public.upload_points('{"lat":0}'::jsonb)$$, '22023', null::text, 'bukan array ditolak');
select throws_ok($$select public.upload_points(null)$$, '22023', null::text, 'null ditolak');
select throws_ok($$select public.upload_points('[1]'::jsonb)$$, '22023', null::text, 'elemen bukan objek ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lng', 0, 'recorded_at', now())))$$, '22023', null::text, 'lat hilang ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 'abc', 'lng', 0, 'recorded_at', now())))$$, '22023', null::text, 'lat bertipe string ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 91, 'lng', 0, 'recorded_at', now())))$$, '22023', null::text, 'lat 91 ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', -91, 'lng', 0, 'recorded_at', now())))$$, '22023', null::text, 'lat -91 ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 0, 'lng', 181, 'recorded_at', now())))$$, '22023', null::text, 'lng 181 ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 0, 'lng', -181, 'recorded_at', now())))$$, '22023', null::text, 'lng -181 ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 0, 'lng', 0, 'battery_pct', 101, 'recorded_at', now())))$$,
  '22023', null::text, 'battery_pct 101 ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 0, 'lng', 0, 'recorded_at', 'bukan tanggal')))$$,
  '22023', null::text, 'recorded_at tidak terbaca ditolak');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 0, 'lng', 0, 'recorded_at', now() + interval '1 hour')))$$,
  'TH001', null::text, 'recorded_at 1 jam di masa depan ditolak dengan TH001 (bukan 22023)');
-- batch campuran: titik sehat + titik masa depan, seluruh batch ditolak dan tidak sebagian tersimpan
select throws_ok($$select public.upload_points(jsonb_build_array(
  pg_temp.pt(-6.2, 106.8167, 30), pg_temp.pt(-6.2, 106.8167, 31),
  jsonb_build_object('lat', -6.2123457, 'lng', 106.8765431, 'recorded_at', now() + interval '1 hour')))$$,
  'TH001', null::text, 'batch dengan satu titik masa depan ditolak TH001');
select is((select count(*)::int from public.location_points), 5,
  'titik sehat di batch yang ditolak tidak tersimpan (tidak sebagian)');
select alike(pg_temp.try_upload(jsonb_build_array(
    jsonb_build_object('lat', -6.2123457, 'lng', 106.8765431, 'recorded_at', now() + interval '1 hour'))),
  '%jam perangkat tidak sinkron%', 'pesan TH001 menjelaskan jam perangkat');
select unalike(pg_temp.try_upload(jsonb_build_array(
    jsonb_build_object('lat', -6.2123457, 'lng', 106.8765431, 'recorded_at', now() + interval '1 hour'))),
  '%6.2123457%', 'pesan TH001 tidak memuat koordinat');

select is(public.upload_points(jsonb_build_array(
    jsonb_build_object('lat', 90, 'lng', 180, 'recorded_at', now() + interval '4 minutes'))),
  1, 'batas lat 90, lng 180, dan 4 menit di masa depan diterima');
select is(public.upload_points(jsonb_build_array(pg_temp.pt(-6.2, 106.8167, 49 * 60))),
  0, 'titik lebih dari 48 jam dilewati tanpa gagal');
select is(public.upload_points(jsonb_build_array(pg_temp.pt(-6.2, 106.8167, 49 * 60), pg_temp.pt(-6.2, 106.8167, 20))),
  1, 'batch campuran: yang tua dilewati, yang baru masuk');

select unalike(pg_temp.try_upload(jsonb_build_array(
    jsonb_build_object('lat', 91.123456, 'lng', 106.7654321, 'recorded_at', now()))),
  '%91.123456%', 'pesan error rentang tidak memuat lat');
select unalike(pg_temp.try_upload(jsonb_build_array(
    jsonb_build_object('lat', 91.123456, 'lng', 106.7654321, 'recorded_at', now()))),
  '%106.7654321%', 'pesan error rentang tidak memuat lng');
select unalike(pg_temp.try_upload(jsonb_build_array(
    jsonb_build_object('lat', 1.234567, 'lng', 106.7654321, 'recorded_at', 'bukan tanggal'))),
  '%1.234567%', 'pesan error format tidak memuat koordinat');

-- tanpa login
select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 0, 'lng', 0, 'recorded_at', now())))$$,
  '28000', null::text, 'tanpa auth.uid() ditolak');

-- tepat 500 elemen diterima
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is(public.upload_points((
  select jsonb_agg(jsonb_build_object('lat', 0, 'lng', 0, 'recorded_at', now() - interval '2 hours' - g * interval '1 second'))
  from generate_series(1, 500) g)),
  500, 'tepat 500 elemen diterima');

select * from finish();
rollback;
