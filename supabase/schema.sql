-- 크롬 공룡점프 랭킹 스키마 (Supabase SQL Editor에서 실행, 여러 번 실행해도 안전)
create table if not exists public.rankings (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 12),
  time_ms integer not null check (time_ms >= 20000 and time_ms < 3600000),
  created_at timestamptz not null default now()
);

-- 난이도별 랭킹 (easy / normal / hard / extreme)
alter table public.rankings add column if not exists difficulty text not null default 'normal';
alter table public.rankings drop constraint if exists rankings_difficulty_check;
alter table public.rankings add constraint rankings_difficulty_check check (difficulty in ('easy','normal','hard','extreme'));

drop index if exists public.rankings_rank_idx;
create index if not exists rankings_rank_idx2 on public.rankings (difficulty, time_ms asc, created_at asc);

alter table public.rankings enable row level security;

drop policy if exists "rankings readable by all" on public.rankings;
create policy "rankings readable by all" on public.rankings
  for select to anon, authenticated using (true);

-- 직접 쓰기 정책은 만들지 않음 (RPC로만 기록)
revoke insert, update, delete on public.rankings from anon, authenticated;

-- 난이도별 최단 가능 시간(ms) 미만은 거절: 쉬움 36s / 보통 30s / 어려움 23.7s / 완죤어려움 22.5s 가 이론상 최소
create or replace function public.submit_score(p_name text, p_time_ms integer, p_difficulty text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_diff text := coalesce(p_difficulty, 'normal');
  v_min integer;
  v_id bigint;
  v_rank integer;
begin
  if char_length(v_name) < 1 or char_length(v_name) > 12 then
    raise exception 'invalid name';
  end if;
  v_min := case v_diff when 'easy' then 33000 when 'normal' then 28000 when 'hard' then 22000 when 'extreme' then 21000 else null end;
  if v_min is null then
    raise exception 'invalid difficulty';
  end if;
  if p_time_ms is null or p_time_ms < v_min or p_time_ms >= 3600000 then
    raise exception 'invalid time';
  end if;

  insert into rankings (name, time_ms, difficulty) values (v_name, p_time_ms, v_diff) returning id into v_id;

  -- 해당 난이도에서 10위 밖은 삭제
  delete from rankings where id in (
    select id from rankings where difficulty = v_diff
    order by time_ms asc, created_at asc, id asc offset 10
  );

  select r into v_rank from (
    select id, row_number() over (order by time_ms asc, created_at asc, id asc) as r
    from rankings where difficulty = v_diff
  ) t where id = v_id;

  return v_rank; -- 10위 밖이면 null
end;
$$;

-- 예전 버전 클라이언트 호환: 난이도 없이 호출하면 '보통'
create or replace function public.submit_score(p_name text, p_time_ms integer)
returns integer
language sql
security definer
set search_path = public
as $$ select public.submit_score(p_name, p_time_ms, 'normal') $$;

grant execute on function public.submit_score(text, integer, text) to anon, authenticated;
grant execute on function public.submit_score(text, integer) to anon, authenticated;
