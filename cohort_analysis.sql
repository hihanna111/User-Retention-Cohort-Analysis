-- Database processing and cohort table preparation
-- User data cleaning
with users_parsed as (
select
	user_id, 
	signup_datetime, 
	promo_signup_flag,
	case 
            when d <> '' and m <> '' and y <> '' then
                to_date(
                  concat(
                    lpad(trim(d), 2, '0'), '-', -- return a two-character value. If the length is less than 2, a leading 0 is added
                    lpad(trim(m), 2, '0'), '-',
                    case 
                      when length(trim(y)) = 2 then concat('20', trim(y)) -- if the year is stored with only two digits, prepend 20
                      when length(trim(y)) = 4 then trim(y)
                    end
                ),
                    'DD-MM-YYYY'
                )
            else null
        end as signup_ts
from (
-- Split dates into separate parts using '-' as the delimiter
	select
		user_id, 
		signup_datetime, 
		promo_signup_flag,
		split_part(converted_date, '-', 1) as d, -- day
    	split_part(converted_date, '-', 2) as m, -- month
    	split_part(converted_date, '-', 3) as y  -- year
    from (
-- Removed extra spaces and time components
		select
			ur.user_id, 
			ur.signup_datetime, 
			ur.promo_signup_flag,
	---trim(signup_datetime) as trimed_date,
	---trim(split_part(trim(signup_datetime),' ',1)) as date_only,
-- Standardized different delimiters (. / -) into a single format
			replace(replace(replace(trim(split_part(trim(ur.signup_datetime),' ',1)),
            							'.', '-'),
           							 '/', '-'),
            						'-', '-') as converted_date
		from project.cohort_users_raw ur 
    ) as trimed_date 
  ) as users_modified
 ),
 events_parsed as (
 select
	user_id, 
	event_type,
	event_datetime,
	case 
            when d <> '' and m <> '' and y <> '' then
                to_date(
                  concat(
                    lpad(trim(d), 2, '0'), '-', -- Return a two-character value. If the length is less than 2, a leading 0 is added
                    lpad(trim(m), 2, '0'), '-',
                    case 
                      when length(trim(y)) = 2 then concat('20', trim(y)) -- If the year is stored with only two digits, prepend 20
                      when length(trim(y)) = 4 then trim(y)
                    end
                ),
                    'DD-MM-YYYY'
                )
            else null
        end as event_ts               
  from(
    select
		user_id, 
		event_type,
		event_datetime,
		split_part(converted_date, '-', 1) as d, -- day
    	split_part(converted_date, '-', 2) as m, -- month
    	split_part(converted_date, '-', 3) as y  -- year
    from (
-- Removed extra spaces and time components
		select
			er.user_id, 
			er.event_type,
			er.event_datetime,
-- Standardized different delimiters (. / -) into a single format
			replace(replace(replace(trim(split_part(trim(er.event_datetime),' ',1)),
            						'.', '-'),
           						'/', '-'),
            				'-', '-') as converted_date
		from project.cohort_events_raw er
    ) as events_modified 
  ) as separated_parts
 ),
 -- Merge the two tables and calculate cohort metrics
user_activity as (
select
		u.user_id,
        u.promo_signup_flag,
        u.signup_ts,
        e.event_type,
        e.event_ts,
 		date_trunc('month', u.signup_ts) as cohort_month,
 		date_trunc('month', e.event_ts) as activity_month,
		extract(
 			month from age(
 			date_trunc('month', e.event_ts),
 			date_trunc('month', u.signup_ts)
 			)
		)   as month_offset
from users_parsed u
join events_parsed e
	on u.user_id = e.user_id
where u.signup_ts is not null 
	and e.event_ts is not null 
	and e.event_type is not null
	and e.event_type <> 'test_event'
)
-- main select
select 
	promo_signup_flag,
    cohort_month::date as cohort_month,
    month_offset,
    count(distinct user_id) as user_total 
from user_activity 
where activity_month between '2025-01-01' and '2025-06-01'
group by 
	promo_signup_flag,
    cohort_month,
    month_offset
order by
	promo_signup_flag,
    cohort_month,
    month_offset;
