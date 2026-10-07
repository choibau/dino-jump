-- 크롬 공룡점프 랭킹 스키마 (Supabase SQL Editor에서 실행)
create table if not exists public.rankings (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 12),
  time_ms integer not null check (time_ms >= 20000 and time_ms < 3600000),
  created_at timestamptz not null default now()
);

create index if not exists rankings_rank_idx on public.rankings (time_ms asc, created_at asc);

alter table public.rankings enable row level security;

drop policy if exists "rankings readable by all" on public.rankings;
create policy "rankings readable by all" on public.rankings
  for select to anon, authenticated using (true);

-- 직접 쓰기 정책은 만들지 않음 (RPC로만 기록)
revoke insert, update, delete on public.rankings from anon, authenticated;

create or replace function public.submit_score(p_name text, p_time_ms integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id bigint;
  v_rank integer;
begin
  if char_length(v_name) < 1 or char_length(v_name) > 12 then
    raise exception 'invalid name';
  end if;
  if p_time_ms is null or p_time_ms < 20000 or p_time_ms >= 3600000 then
    raise exception 'invalid time';
  end if;

  insert into rankings (name, time_ms) values (v_name, p_time_ms) returning id into v_id;

  -- 10위 밖은 삭제
  delete from rankings where id in (
    select id from rankings order by time_ms asc, created_at asc, id asc offset 10
  );

  select r into v_rank from (
    select id, row_number() over (order by time_ms asc, created_at asc, id asc) as r from rankings
  ) t where id = v_id;

  return v_rank; -- 10위 밖이면 null
end;
$$;

grant execute on function public.submit_score(text, integer) to anon, authenticated;
