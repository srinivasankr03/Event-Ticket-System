-- UTSAV backend: paste this whole file into Supabase > SQL Editor > Run

create table events (
  id bigint generated always as identity primary key,
  title text not null,
  category text not null,
  venue text,
  starts_at timestamptz not null,
  price int not null default 0,
  capacity int not null check (capacity > 0),
  description text,
  icon text default '🎟️',
  created_by uuid references auth.users default auth.uid()
);

create table reservations (
  id bigint generated always as identity primary key,
  event_id bigint references events on delete cascade,
  user_id uuid references auth.users default auth.uid(),
  qty int not null check (qty between 1 and 6),
  status text not null default 'held' check (status in ('held','confirmed','cancelled')),
  expires_at timestamptz
);

alter table events enable row level security;
alter table reservations enable row level security;

create policy "anyone can view events" on events for select using (true);
create policy "signed-in users can host events" on events for insert to authenticated with check (created_by = auth.uid());
create policy "users see their own reservations" on reservations for select to authenticated using (user_id = auth.uid());
-- No direct insert/update on reservations: everything goes through the functions below.

-- Tickets left per event (expired holds are not counted)
create or replace function event_availability()
returns table(event_id bigint, left_count int)
language sql security definer as $$
  select e.id,
         (e.capacity - coalesce(sum(r.qty) filter (
            where r.status = 'confirmed' or (r.status = 'held' and r.expires_at > now())), 0))::int
  from events e left join reservations r on r.event_id = e.id
  group by e.id
$$;

-- Hold tickets for 10 minutes (row lock stops two people grabbing the last ticket)
create or replace function reserve_tickets(p_event bigint, p_qty int)
returns reservations
language plpgsql security definer as $$
declare ev events; taken int; r reservations;
begin
  if auth.uid() is null then raise exception 'Please sign in first'; end if;
  select * into ev from events where id = p_event for update;
  if not found then raise exception 'Event not found'; end if;
  select coalesce(sum(qty), 0) into taken from reservations
    where event_id = p_event and (status = 'confirmed' or (status = 'held' and expires_at > now()));
  if ev.capacity - taken < p_qty then raise exception 'Not enough tickets left'; end if;
  insert into reservations(event_id, user_id, qty, expires_at)
    values (p_event, auth.uid(), p_qty, now() + interval '10 minutes') returning * into r;
  return r;
end $$;

create or replace function confirm_reservation(p_id bigint)
returns void language plpgsql security definer as $$
begin
  update reservations set status = 'confirmed', expires_at = null
    where id = p_id and user_id = auth.uid() and status = 'held' and expires_at > now();
  if not found then raise exception 'This hold has expired. Please reserve again.'; end if;
end $$;

create or replace function cancel_reservation(p_id bigint)
returns void language sql security definer as $$
  update reservations set status = 'cancelled'
    where id = p_id and user_id = auth.uid() and status in ('held','confirmed')
$$;

-- Sample events
insert into events(title, category, venue, starts_at, price, capacity, description, icon) values
('Monsoon Beats Open-Air Festival','Music','Marina Open Grounds, Chennai','2026-11-14 18:00+05:30',1999,250,'Two stages, indie bands and DJs under the open sky.','🎸'),
('Founders & Funders Breakfast','Business','T-Hub, Hyderabad','2026-11-20 08:30+05:30',1499,80,'Early-stage founders meet angel investors over breakfast.','🤝'),
('Dosa to Dumplings Food Walk','Food & Drink','Mylapore, Chennai','2026-11-22 16:00+05:30',699,40,'A guided walk through ten legendary street food stops.','🥟'),
('Build with AI Weekend','Technology','IIT Madras Research Park','2026-12-05 09:00+05:30',0,120,'A free weekend hackathon for students and working professionals.','💻'),
('Esports Open: Chennai Qualifiers','Gaming','Express Avenue Arena','2026-12-13 11:00+05:30',499,200,'Watch regional teams fight for a place in the national finals.','🎮'),
('Product Managers Meetup','Business','Bangalore Tech Park','2026-12-19 17:30+05:30',299,100,'Talks and portfolio reviews with hiring managers.','📊');
