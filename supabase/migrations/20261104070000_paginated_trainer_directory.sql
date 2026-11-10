create or replace function public.search_trainer_directory(
  search_email text default null,
  page_offset integer default 0,
  page_size integer default 20
)
returns table (
  trainer_id uuid,
  first_name text,
  last_name text,
  headline text,
  bio text,
  specialties text[],
  years_experience integer,
  average_rating numeric,
  rating_count bigint
)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  term text := lower(trim(coalesce(search_email, '')));
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if public.current_account_role() is distinct from 'client' then
    raise exception 'Client account required';
  end if;
  if length(term) > 100 then
    raise exception 'Email search is too long';
  end if;
  if page_offset < 0 or page_offset > 100000 then
    raise exception 'Invalid page offset';
  end if;
  if page_size < 1 or page_size > 50 then
    raise exception 'Page size must be between 1 and 50';
  end if;

  return query
    select tp.trainer_id,
           coalesce(p.first_name, ''),
           coalesce(p.last_name, ''),
           tp.headline,
           tp.bio,
           tp.specialties,
           tp.years_experience,
           stats.average_rating,
           coalesce(stats.rating_count, 0)::bigint
    from public.trainer_profiles tp
    join public.account_roles ar
      on ar.user_id = tp.trainer_id and ar.role = 'trainer'
    left join public.profiles p on p.user_id = tp.trainer_id
    left join auth.users u on u.id = tp.trainer_id
    left join lateral (
      select avg(t.rating)::numeric(3,2) as average_rating,
             count(*)::bigint as rating_count
      from public.trainer_testimonials t
      where t.trainer_id = tp.trainer_id and t.status = 'approved'
    ) stats on true
    where (term = '' or position(term in lower(coalesce(u.email, ''))) > 0)
    order by stats.average_rating desc nulls last,
             stats.rating_count desc,
             tp.trainer_id
    limit page_size offset page_offset;
end;
$function$;

revoke all on function public.search_trainer_directory(text, integer, integer)
  from public;
grant execute on function public.search_trainer_directory(text, integer, integer)
  to authenticated;
