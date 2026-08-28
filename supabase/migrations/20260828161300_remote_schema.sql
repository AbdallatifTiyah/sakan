SET local check_function_bodies = off;

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON SEQUENCES FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON SEQUENCES FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON SEQUENCES FROM "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "service_role";

CREATE EXTENSION "pg_cron";

CREATE SEQUENCE "public"."areas_id_seq" AS integer INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1 NO CYCLE;

CREATE SEQUENCE "public"."cities_id_seq" AS integer INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1 NO CYCLE;

CREATE SEQUENCE "public"."events_id_seq" AS bigint INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1 NO CYCLE;

CREATE SEQUENCE "public"."listing_ref_seq" AS bigint INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1000 CACHE 1 NO CYCLE;

CREATE SEQUENCE "public"."request_ref_seq" AS bigint INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 500 CACHE 1 NO CYCLE;

CREATE TABLE "public"."areas" (
  "id"         integer NOT NULL DEFAULT nextval('public.areas_id_seq'::regclass),
  "city_id"    integer NOT NULL,
  "name_ar"    text    NOT NULL,
  "slug"       text    NOT NULL,
  "sort_order" integer NOT NULL DEFAULT 100,
  CONSTRAINT "areas_city_id_slug_key" UNIQUE (city_id, slug),
  CONSTRAINT "areas_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."areas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."cities" (
  "id"        integer NOT NULL DEFAULT nextval('public.cities_id_seq'::regclass),
  "name_ar"   text    NOT NULL,
  "slug"      text    NOT NULL,
  "is_active" boolean NOT NULL DEFAULT false,
  CONSTRAINT "cities_pkey" PRIMARY KEY (id),
  CONSTRAINT "cities_slug_key" UNIQUE (slug)
);

ALTER TABLE "public"."cities"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."contact_requests" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "listing_id"   uuid                     NOT NULL,
  "seeker_id"    uuid,
  "seeker_phone" text,
  "seeker_name"  text,
  "request_id"   uuid,
  "agent_id"     uuid,
  "agent_notes"  text,
  "outcome_at"   timestamp with time zone,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "contact_requests_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."contact_requests"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."events" (
  "id"         bigint                   NOT NULL DEFAULT nextval('public.events_id_seq'::regclass),
  "event_type" text                     NOT NULL,
  "seeker_id"  uuid,
  "listing_id" uuid,
  "request_id" uuid,
  "meta"       jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "events_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."events"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."listing_safety" (
  "listing_id"         uuid                     NOT NULL,
  "agent_id"           uuid,
  "visit_date"         date                     NOT NULL,
  "room_exists"        boolean                  NOT NULL DEFAULT false,
  "photos_match"       boolean                  NOT NULL DEFAULT false,
  "door_lock"          boolean                  NOT NULL DEFAULT false,
  "no_indoor_cameras"  boolean                  NOT NULL DEFAULT false,
  "occupants_verified" boolean                  NOT NULL DEFAULT false,
  "exterior_lighting"  boolean,
  "gas_detector"       boolean,
  "notes"              text,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "listing_safety_pkey" PRIMARY KEY (listing_id)
);

ALTER TABLE "public"."listing_safety"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."listings" (
  "id"                uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "ref"               text,
  "owner_id"          uuid,
  "agent_id"          uuid,
  "city_id"           integer                  NOT NULL,
  "area_id"           integer                  NOT NULL,
  "landmark"          text,
  "exact_address"     text,
  "title"             text                     NOT NULL,
  "description"       text,
  "price"             numeric(10,2)            NOT NULL,
  "bills_included"    boolean                  NOT NULL DEFAULT false,
  "deposit"           numeric(10,2),
  "furnished"         boolean                  NOT NULL DEFAULT true,
  "rooms_total"       smallint,
  "occupants_now"     smallint,
  "occupants_note"    text,
  "available_from"    date,
  "min_stay_months"   smallint,
  "images"            jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "reject_reason"     text,
  "published_at"      timestamp with time zone,
  "last_confirmed_at" timestamp with time zone,
  "expires_at"        timestamp with time zone,
  "rented_at"         timestamp with time zone,
  "view_count"        integer                  NOT NULL DEFAULT 0,
  "created_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "confirm_token"     uuid                     NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT "listings_pkey" PRIMARY KEY (id),
  CONSTRAINT "listings_price_check" CHECK ((price >= (0)::numeric)),
  CONSTRAINT "listings_ref_key" UNIQUE (ref)
);

ALTER TABLE "public"."listings"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."owner_fees" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "listing_id"         uuid                     NOT NULL,
  "contact_request_id" uuid,
  "amount_base"        numeric(10,2)            NOT NULL DEFAULT 200,
  "promo_code"         text,
  "amount_due"         numeric(10,2),
  "collected_by"       uuid,
  "collected_at"       timestamp with time zone,
  "note"               text,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "owner_fees_contact_request_id_key" UNIQUE (contact_request_id),
  CONSTRAINT "owner_fees_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."owner_fees"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."profiles" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "auth_uid"           uuid,
  "first_name"         text                     NOT NULL,
  "full_name"          text,
  "phone"              text,
  "org_name"           text,
  "city_id"            integer,
  "verification_level" smallint                 NOT NULL DEFAULT 0,
  "verified_at"        timestamp with time zone,
  "is_blocked"         boolean                  NOT NULL DEFAULT false,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "profiles_auth_uid_key" UNIQUE (auth_uid),
  CONSTRAINT "profiles_pkey" PRIMARY KEY (id),
  CONSTRAINT "profiles_verification_level_check" CHECK (((verification_level >= 0) AND (verification_level <= 4)))
);

ALTER TABLE "public"."profiles"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."promo_codes" (
  "code"         text     NOT NULL,
  "discount_pct" smallint NOT NULL,
  "max_uses"     integer,
  "used_count"   integer  NOT NULL DEFAULT 0,
  "valid_until"  date,
  "is_active"    boolean  NOT NULL DEFAULT true,
  CONSTRAINT "promo_codes_discount_pct_check" CHECK (((discount_pct >= 0) AND (discount_pct <= 100))),
  CONSTRAINT "promo_codes_pkey" PRIMARY KEY (code)
);

ALTER TABLE "public"."promo_codes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."reports" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "listing_id"     uuid,
  "reporter_id"    uuid,
  "reporter_phone" text,
  "details"        text,
  "action_note"    text,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "reports_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."reports"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."reviews" (
  "id"                         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "listing_id"                 uuid                     NOT NULL,
  "seeker_id"                  uuid,
  "r_maintenance"              smallint,
  "r_quiet"                    smallint,
  "r_accuracy"                 smallint,
  "r_safety_night"             smallint,
  "entered_without_permission" boolean,
  "deposit_returned"           boolean,
  "is_published"               boolean                  NOT NULL DEFAULT false,
  "created_at"                 timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "reviews_pkey" PRIMARY KEY (id),
  CONSTRAINT "reviews_r_accuracy_check" CHECK (((r_accuracy >= 1) AND (r_accuracy <= 5))),
  CONSTRAINT "reviews_r_maintenance_check" CHECK (((r_maintenance >= 1) AND (r_maintenance <= 5))),
  CONSTRAINT "reviews_r_quiet_check" CHECK (((r_quiet >= 1) AND (r_quiet <= 5))),
  CONSTRAINT "reviews_r_safety_night_check" CHECK (((r_safety_night >= 1) AND (r_safety_night <= 5)))
);

ALTER TABLE "public"."reviews"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."seeker_requests" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "ref"             text,
  "seeker_id"       uuid,
  "city_id"         integer                  NOT NULL,
  "area_ids"        integer[]                NOT NULL DEFAULT '{}'::integer[],
  "budget_max"      numeric(10,2)            NOT NULL,
  "furnished_pref"  boolean,
  "move_in_date"    date,
  "min_stay_months" smallint,
  "smoker"          boolean,
  "lifestyle_tags"  text[]                   DEFAULT '{}'::text[],
  "note"            text,
  "expires_at"      timestamp with time zone,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "seeker_requests_pkey" PRIMARY KEY (id),
  CONSTRAINT "seeker_requests_ref_key" UNIQUE (ref)
);

ALTER TABLE "public"."seeker_requests"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."verification_log" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "subject_type"  text                     NOT NULL,
  "subject_id"    uuid                     NOT NULL,
  "action"        text                     NOT NULL,
  "from_level"    text,
  "to_level"      text,
  "result"        text                     NOT NULL,
  "reject_reason" text,
  "verifier_id"   uuid,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "verification_log_pkey" PRIMARY KEY (id),
  CONSTRAINT "verification_log_result_check" CHECK ((result = ANY (ARRAY['passed'::text, 'failed'::text]))),
  CONSTRAINT "verification_log_subject_type_check" CHECK ((subject_type = ANY (ARRAY['user'::text, 'listing'::text])))
);

ALTER TABLE "public"."verification_log"
  ENABLE ROW LEVEL SECURITY;

ALTER SEQUENCE "public"."areas_id_seq" OWNED BY "public"."areas"."id";

ALTER SEQUENCE "public"."cities_id_seq" OWNED BY "public"."cities"."id";

ALTER SEQUENCE "public"."events_id_seq" OWNED BY "public"."events"."id";

CREATE TYPE "public"."contact_status" AS ENUM (
  'new',
  'forwarded',
  'owner_responded',
  'viewing_set',
  'rented',
  'dead'
);

ALTER TABLE "public"."contact_requests"
  ADD COLUMN "status" public.contact_status NOT NULL DEFAULT 'new'::public.contact_status;

CREATE TYPE "public"."event_source" AS ENUM (
  'system',
  'agent',
  'user'
);

ALTER TABLE "public"."contact_requests"
  ADD COLUMN "outcome_source" public.event_source;

ALTER TABLE "public"."events"
  ADD COLUMN "source" public.event_source NOT NULL DEFAULT 'system'::public.event_source;

CREATE TYPE "public"."fee_status" AS ENUM (
  'due',
  'collected',
  'waived',
  'lost'
);

ALTER TABLE "public"."owner_fees"
  ADD COLUMN "status" public.fee_status NOT NULL DEFAULT 'due'::public.fee_status;

CREATE TYPE "public"."gender_policy" AS ENUM (
  'female',
  'male',
  'mixed'
);

ALTER TABLE "public"."listings"
  ADD COLUMN "gender_pol" public.gender_policy NOT NULL DEFAULT 'mixed'::public.gender_policy;

CREATE TYPE "public"."gender_type" AS ENUM (
  'female',
  'male'
);

ALTER TABLE "public"."profiles"
  ADD COLUMN "gender" public.gender_type;

ALTER TABLE "public"."seeker_requests"
  ADD COLUMN "gender" public.gender_type;

CREATE TYPE "public"."listing_kind" AS ENUM (
  'room_shared',
  'studio',
  'apartment'
);

ALTER TABLE "public"."listings"
  ADD COLUMN "kind" public.listing_kind NOT NULL DEFAULT 'room_shared'::public.listing_kind;

ALTER TABLE "public"."seeker_requests"
  ADD COLUMN "kind_pref" public.listing_kind;

CREATE TYPE "public"."listing_status" AS ENUM (
  'draft',
  'pending',
  'published',
  'rejected',
  'reserved',
  'rented',
  'expired'
);

ALTER TABLE "public"."listings"
  ADD COLUMN "status" public.listing_status NOT NULL DEFAULT 'pending'::public.listing_status;

CREATE TYPE "public"."listing_verification" AS ENUM (
  'none',
  'desk',
  'field'
);

ALTER TABLE "public"."listings"
  ADD COLUMN "verification" public.listing_verification NOT NULL DEFAULT 'none'::public.listing_verification;

CREATE TYPE "public"."occupation_type" AS ENUM (
  'student',
  'employee',
  'other'
);

ALTER TABLE "public"."profiles"
  ADD COLUMN "occupation" public.occupation_type DEFAULT 'other'::public.occupation_type;

CREATE TYPE "public"."report_category" AS ENUM (
  'fake_listing',
  'already_rented',
  'harassment',
  'entered_room',
  'deposit',
  'camera',
  'other'
);

ALTER TABLE "public"."reports"
  ADD COLUMN "category" public.report_category NOT NULL;

CREATE TYPE "public"."report_status" AS ENUM (
  'open',
  'investigating',
  'actioned',
  'dismissed'
);

ALTER TABLE "public"."reports"
  ADD COLUMN "status" public.report_status NOT NULL DEFAULT 'open'::public.report_status;

CREATE TYPE "public"."request_status" AS ENUM (
  'pending',
  'published',
  'closed'
);

ALTER TABLE "public"."seeker_requests"
  ADD COLUMN "status" public.request_status NOT NULL DEFAULT 'pending'::public.request_status;

CREATE TYPE "public"."review_stage" AS ENUM (
  'day30',
  'move_out'
);

ALTER TABLE "public"."reviews"
  ADD COLUMN "stage" public.review_stage NOT NULL;

CREATE TYPE "public"."user_role" AS ENUM (
  'seeker',
  'owner',
  'agent',
  'admin'
);

ALTER TABLE "public"."events"
  ADD COLUMN "actor_role" public.user_role;

ALTER TABLE "public"."profiles"
  ADD COLUMN "role" public.user_role NOT NULL DEFAULT 'seeker'::public.user_role;

CREATE OR REPLACE FUNCTION public.block_camera_listings()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.no_indoor_cameras = false then
    update listings
       set status = 'rejected',
           reject_reason = 'كاميرا داخلية — مرفوض نهائياً'
     where id = new.listing_id;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.compute_fee_due()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
declare pct smallint := 0;
begin
  if new.promo_code is not null then
    select discount_pct into pct from promo_codes
     where code = new.promo_code and is_active
       and (valid_until is null or valid_until >= current_date)
       and (max_uses is null or used_count < max_uses);
    pct := coalesce(pct, 0);
  end if;
  new.amount_due := round(new.amount_base * (100 - pct) / 100.0, 2);
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.confirm_listing_available (
  p_ref   text,
  p_token uuid
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  n int := 0;
  v_id uuid;
begin
  update listings
     set status            = 'published',
         last_confirmed_at = now(),
         expires_at        = now() + interval '21 days'
   where ref = p_ref
     and confirm_token = p_token
     and status in ('published', 'expired')
  returning id into v_id;

  get diagnostics n = row_count;

  if n > 0 then
    insert into events (event_type, source, listing_id, meta)
    values ('listing_confirmed', 'user', v_id, '{}'::jsonb);
  end if;

  return n > 0;
end
$function$;

CREATE OR REPLACE FUNCTION public.expire_stale_listings()
  RETURNS integer
  LANGUAGE plpgsql
  AS $function$
declare n int;
begin
  with expired as (
    update listings set status='expired'
     where status='published' and expires_at is not null and expires_at < now()
    returning id
  )
  select count(*) into n from expired;

  insert into events (event_type, source, listing_id, meta)
  select 'listing_expired', 'system', id, '{}'::jsonb
  from listings where status='expired' and updated_at > now() - interval '5 minutes';

  return n;
end $function$;

CREATE OR REPLACE FUNCTION public.force_pending_on_insert()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.status := 'pending';
  new.verification := 'none';
  new.published_at := null;
  new.expires_at := null;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.is_field_verified (
  p_listing uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  AS $function$
  select coalesce(bool_and(x), false) from (
    select unnest(array[room_exists, photos_match, door_lock,
                        no_indoor_cameras, occupants_verified, visit_date is not null])
    from listing_safety where listing_id = p_listing
  ) t(x);
$function$;

CREATE OR REPLACE FUNCTION public.on_contact_rented()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.status = 'rented' and old.status is distinct from 'rented' then
    new.outcome_at := now();
    update listings set status='rented' where id = new.listing_id;
    insert into owner_fees (listing_id, contact_request_id, amount_base)
    values (new.listing_id, new.id, 200)
    on conflict do nothing;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.on_listing_publish()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.updated_at := now();
  if new.status = 'published' and (old.status is distinct from 'published') then
    new.published_at      := coalesce(new.published_at, now());
    new.last_confirmed_at := now();
    new.expires_at        := now() + interval '21 days';
  end if;
  if new.status = 'rented' and old.status is distinct from 'rented' then
    new.rented_at := now();
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.publish_reviews_at_threshold()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if (select count(*) from reviews where listing_id = new.listing_id) >= 3 then
    update reviews set is_published = true where listing_id = new.listing_id;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.sakan_match_score (
  p_area_ids   integer[],
  p_budget     numeric,
  p_gender     public.gender_type,
  p_kind       public.listing_kind,
  p_move_in    date,
  l_area       integer,
  l_price      numeric,
  l_gender_pol public.gender_policy,
  l_kind       public.listing_kind,
  l_available  date
)
  RETURNS integer
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare s int := 0;
begin
  -- المنطقة · 30
  if p_area_ids is null or array_length(p_area_ids,1) is null then s := s + 15;
  elsif l_area = any(p_area_ids) then s := s + 30;
  end if;

  -- الميزانية · 30  (تحت الميزانية = كامل، فوقها بـ15% = نصف)
  if l_price <= p_budget then s := s + 30;
  elsif l_price <= p_budget * 1.15 then s := s + 15;
  end if;

  -- نظام السكن · 25  (شرط إقصائي فعلياً)
  if l_gender_pol = 'mixed' then s := s + 15;
  elsif p_gender is null then s := s + 5;
  elsif (p_gender = 'female' and l_gender_pol = 'female')
     or (p_gender = 'male'   and l_gender_pol = 'male') then s := s + 25;
  else return 0;   -- تعارض كامل
  end if;

  -- النوع · 10
  if p_kind is null or p_kind = l_kind then s := s + 10; end if;

  -- تاريخ الدخول · 5
  if p_move_in is null or l_available is null or l_available <= p_move_in + 14 then
    s := s + 5;
  end if;

  return least(s, 100);
end $function$;

CREATE OR REPLACE FUNCTION public.set_listing_ref()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.ref is null then
    new.ref := 'SK-' || nextval('listing_ref_seq')::text;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.set_request_ref()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.ref is null then new.ref := 'RQ-' || nextval('request_ref_seq')::text; end if;
  new.status := 'pending';
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.submit_listing (
  p_name      text,
  p_phone     text,
  p_title     text,
  p_area      integer,
  p_price     numeric,
  p_kind      text,
  p_pol       text,
  p_furnished boolean,
  p_from      date    DEFAULT NULL::date,
  p_occ       text    DEFAULT NULL::text,
  p_landmark  text    DEFAULT NULL::text,
  p_desc      text    DEFAULT NULL::text
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare v_owner uuid; v_ref text; v_city int;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  -- إعادة استخدام المالك إن كان رقمه مسجّلاً سابقاً
  select id into v_owner from profiles
   where phone = trim(p_phone) and role = 'owner' limit 1;

  if v_owner is null then
    insert into profiles (role, first_name, phone, city_id)
    values ('owner', trim(p_name), trim(p_phone), v_city)
    returning id into v_owner;
  end if;

  insert into listings (owner_id, city_id, area_id, title, description, price,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''))
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;

CREATE OR REPLACE FUNCTION public.submit_request (
  p_name       text,
  p_phone      text,
  p_gender     text,
  p_occupation text,
  p_budget     numeric,
  p_areas      integer[],
  p_move_in    date      DEFAULT NULL::date,
  p_tags       text[]    DEFAULT '{}'::text[],
  p_note       text      DEFAULT NULL::text
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare v_seeker uuid; v_ref text; v_city int;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select coalesce(min(city_id), (select id from cities where slug='ramallah'))
    into v_city from areas where id = any(coalesce(p_areas,'{}'));

  select id into v_seeker from profiles
   where phone = trim(p_phone) and role = 'seeker' limit 1;

  if v_seeker is null then
    insert into profiles (role, first_name, phone, gender, occupation, city_id)
    values ('seeker', trim(p_name), trim(p_phone),
            nullif(p_gender,'')::gender_type,
            coalesce(nullif(p_occupation,''),'other')::occupation_type, v_city)
    returning id into v_seeker;
  end if;

  insert into seeker_requests (seeker_id, city_id, area_ids, budget_max, gender,
                               move_in_date, lifestyle_tags, note)
  values (v_seeker, v_city, coalesce(p_areas,'{}'), p_budget,
          nullif(p_gender,'')::gender_type, p_move_in,
          coalesce(p_tags,'{}'), nullif(trim(coalesce(p_note,'')),''))
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('request_created','user','seeker', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;

CREATE OR REPLACE FUNCTION public.suspend_on_serious_report()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.category in ('harassment','entered_room','camera','fake_listing') then
    update listings set status='rejected',
           reject_reason='موقوف بانتظار التحقيق'
     where id = new.listing_id and status='published';
  end if;
  return new;
end $function$;

ALTER TABLE "public"."areas"
  ADD CONSTRAINT "areas_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE CASCADE;

ALTER TABLE "public"."listings"
  ADD CONSTRAINT "listings_area_id_fkey" FOREIGN KEY (area_id) REFERENCES public.areas(id);

ALTER TABLE "public"."listings"
  ADD CONSTRAINT "listings_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id);

ALTER TABLE "public"."contact_requests"
  ADD CONSTRAINT "contact_requests_listing_id_fkey" FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;

ALTER TABLE "public"."events"
  ADD CONSTRAINT "events_listing_id_fkey" FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE SET NULL;

ALTER TABLE "public"."listing_safety"
  ADD CONSTRAINT "listing_safety_listing_id_fkey" FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;

ALTER TABLE "public"."owner_fees"
  ADD CONSTRAINT "owner_fees_contact_request_id_fkey" FOREIGN KEY (contact_request_id) REFERENCES public.contact_requests(id) ON DELETE CASCADE;

ALTER TABLE "public"."owner_fees"
  ADD CONSTRAINT "owner_fees_listing_id_fkey" FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id);

ALTER TABLE "public"."contact_requests"
  ADD CONSTRAINT "contact_requests_agent_id_fkey" FOREIGN KEY (agent_id) REFERENCES public.profiles(id);

ALTER TABLE "public"."contact_requests"
  ADD CONSTRAINT "contact_requests_seeker_id_fkey" FOREIGN KEY (seeker_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE "public"."events"
  ADD CONSTRAINT "events_seeker_id_fkey" FOREIGN KEY (seeker_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE "public"."listing_safety"
  ADD CONSTRAINT "listing_safety_agent_id_fkey" FOREIGN KEY (agent_id) REFERENCES public.profiles(id);

ALTER TABLE "public"."listings"
  ADD CONSTRAINT "listings_agent_id_fkey" FOREIGN KEY (agent_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE "public"."listings"
  ADD CONSTRAINT "listings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE "public"."owner_fees"
  ADD CONSTRAINT "owner_fees_collected_by_fkey" FOREIGN KEY (collected_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."owner_fees"
  ADD CONSTRAINT "owner_fees_promo_code_fkey" FOREIGN KEY (promo_code) REFERENCES public.promo_codes(code);

ALTER TABLE "public"."reports"
  ADD CONSTRAINT "reports_listing_id_fkey" FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE SET NULL;

ALTER TABLE "public"."reports"
  ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY (reporter_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE "public"."reviews"
  ADD CONSTRAINT "reviews_listing_id_fkey" FOREIGN KEY (listing_id) REFERENCES public.listings(id) ON DELETE CASCADE;

ALTER TABLE "public"."reviews"
  ADD CONSTRAINT "reviews_listing_id_seeker_id_stage_key" UNIQUE (listing_id, seeker_id, stage);

ALTER TABLE "public"."reviews"
  ADD CONSTRAINT "reviews_seeker_id_fkey" FOREIGN KEY (seeker_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE "public"."seeker_requests"
  ADD CONSTRAINT "seeker_requests_city_id_fkey" FOREIGN KEY (city_id) REFERENCES public.cities(id);

ALTER TABLE "public"."contact_requests"
  ADD CONSTRAINT "contact_requests_request_id_fkey" FOREIGN KEY (request_id) REFERENCES public.seeker_requests(id) ON DELETE SET NULL;

ALTER TABLE "public"."events"
  ADD CONSTRAINT "events_request_id_fkey" FOREIGN KEY (request_id) REFERENCES public.seeker_requests(id) ON DELETE SET NULL;

ALTER TABLE "public"."seeker_requests"
  ADD CONSTRAINT "seeker_requests_seeker_id_fkey" FOREIGN KEY (seeker_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."verification_log"
  ADD CONSTRAINT "verification_log_verifier_id_fkey" FOREIGN KEY (verifier_id) REFERENCES public.profiles(id);

CREATE VIEW "public"."v_kpi_core" AS  SELECT ( SELECT count(*) AS count
           FROM public.listings
          WHERE (listings.status = 'published'::public.listing_status)) AS active_listings,
    ( SELECT count(*) AS count
           FROM public.listings
          WHERE ((listings.status = 'published'::public.listing_status) AND (listings.verification = 'field'::public.listing_verification))) AS field_verified,
    ( SELECT count(*) AS count
           FROM public.contact_requests
          WHERE (contact_requests.created_at > (now() - '30 days'::interval))) AS contacts_30d,
    ( SELECT count(*) AS count
           FROM public.contact_requests
          WHERE (contact_requests.status = 'rented'::public.contact_status)) AS rentals_total,
    ( SELECT count(*) AS count
           FROM public.contact_requests
          WHERE ((contact_requests.status = 'rented'::public.contact_status) AND (contact_requests.outcome_at > (now() - '30 days'::interval)))) AS rentals_30d,
    ( SELECT count(*) AS count
           FROM public.seeker_requests
          WHERE (seeker_requests.status = 'published'::public.request_status)) AS active_seekers,
    ( SELECT count(*) AS count
           FROM public.listings
          WHERE (listings.status = 'pending'::public.listing_status)) AS awaiting_review,
    ( SELECT count(*) AS count
           FROM public.reports
          WHERE (reports.status = 'open'::public.report_status)) AS open_reports,
    ( SELECT COALESCE(sum(owner_fees.amount_due), (0)::numeric) AS "coalesce"
           FROM public.owner_fees
          WHERE (owner_fees.status = 'due'::public.fee_status)) AS fees_due,
    ( SELECT COALESCE(sum(owner_fees.amount_due), (0)::numeric) AS "coalesce"
           FROM public.owner_fees
          WHERE (owner_fees.status = 'collected'::public.fee_status)) AS fees_collected;

CREATE VIEW "public"."v_kpi_quality" AS  SELECT round(((100.0 * (NULLIF(( SELECT count(*) AS count
           FROM public.contact_requests
          WHERE (contact_requests.status = 'rented'::public.contact_status)), 0))::numeric) / (NULLIF(( SELECT count(*) AS count
           FROM public.contact_requests), 0))::numeric), 1) AS contact_to_rent_pct,
    ( SELECT percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((EXTRACT(day FROM (listings.rented_at - listings.published_at)))::double precision)) AS percentile_cont
           FROM public.listings
          WHERE (listings.rented_at IS NOT NULL)) AS median_days_to_rent,
    round(((100.0 * (( SELECT count(*) AS count
           FROM ( SELECT listings.owner_id
                   FROM public.listings
                  WHERE ((listings.created_at > (now() - '180 days'::interval)) AND (listings.owner_id IS NOT NULL))
                  GROUP BY listings.owner_id
                 HAVING (count(*) > 1)) x))::numeric) / (NULLIF(( SELECT count(DISTINCT listings.owner_id) AS count
           FROM public.listings
          WHERE (listings.created_at > (now() - '180 days'::interval))), 0))::numeric), 1) AS owner_repeat_pct,
    round(((100.0 * (( SELECT count(*) AS count
           FROM public.listings
          WHERE ((listings.status = 'published'::public.listing_status) AND (listings.verification = 'field'::public.listing_verification))))::numeric) / (NULLIF(( SELECT count(*) AS count
           FROM public.listings
          WHERE (listings.status = 'published'::public.listing_status)), 0))::numeric), 1) AS field_verified_pct,
    round(((100.0 * (( SELECT count(*) AS count
           FROM public.reports))::numeric) / (NULLIF(( SELECT count(*) AS count
           FROM public.listings), 0))::numeric), 2) AS report_rate_pct;

CREATE VIEW "public"."v_listings_public" WITH (security_barrier=true) AS  SELECT l.id,
    l.ref,
    l.title,
    l.description,
    c.name_ar AS city,
    c.slug AS city_slug,
    a.name_ar AS area,
    a.id AS area_id,
    l.landmark,
    l.kind,
    l.price,
    l.bills_included,
    l.deposit,
    l.gender_pol,
    l.furnished,
    l.rooms_total,
    l.occupants_now,
    l.occupants_note,
    l.available_from,
    l.min_stay_months,
    l.images,
    l.verification,
    l.published_at,
    l.expires_at,
    l.view_count,
    COALESCE((p.verification_level)::integer, 0) AS owner_level,
    s.visit_date,
    s.door_lock,
    s.no_indoor_cameras,
    s.room_exists,
    s.photos_match,
    s.occupants_verified,
    s.exterior_lighting,
    s.gas_detector,
    ( SELECT count(*) AS count
           FROM public.reviews r
          WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_count,
    ( SELECT round(avg((((((r.r_maintenance + r.r_quiet) + r.r_accuracy) + r.r_safety_night))::numeric / 4.0)), 1) AS round
           FROM public.reviews r
          WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_avg
   FROM ((((public.listings l
     JOIN public.cities c ON ((c.id = l.city_id)))
     JOIN public.areas a ON ((a.id = l.area_id)))
     LEFT JOIN public.profiles p ON ((p.id = l.owner_id)))
     LEFT JOIN public.listing_safety s ON ((s.listing_id = l.id)))
  WHERE (l.status = 'published'::public.listing_status);

CREATE VIEW "public"."v_requests_public" WITH (security_barrier=true) AS  SELECT r.id,
    r.ref,
    r.budget_max,
    r.gender,
    r.kind_pref,
    r.furnished_pref,
    r.move_in_date,
    r.min_stay_months,
    r.smoker,
    r.lifestyle_tags,
    r.note,
    r.area_ids,
    c.name_ar AS city,
    r.created_at,
    p.first_name,
    p.occupation,
    COALESCE((p.verification_level)::integer, 0) AS seeker_level
   FROM ((public.seeker_requests r
     JOIN public.cities c ON ((c.id = r.city_id)))
     LEFT JOIN public.profiles p ON ((p.id = r.seeker_id)))
  WHERE (r.status = 'published'::public.request_status);

CREATE VIEW "public"."v_reverse_matches" AS  SELECT l.id AS listing_id,
    l.ref AS listing_ref,
    r.id AS request_id,
    r.ref AS request_ref,
    p.first_name,
    p.occupation,
    p.verification_level,
    p.phone,
    r.budget_max,
    r.move_in_date,
    public.sakan_match_score(r.area_ids, r.budget_max, r.gender, r.kind_pref, r.move_in_date, l.area_id, l.price, l.gender_pol, l.kind, l.available_from) AS score
   FROM ((public.listings l
     JOIN public.seeker_requests r ON (((r.city_id = l.city_id) AND (r.status = 'published'::public.request_status))))
     LEFT JOIN public.profiles p ON ((p.id = r.seeker_id)))
  WHERE (l.status = ANY (ARRAY['published'::public.listing_status, 'pending'::public.listing_status]));

CREATE INDEX idx_contact_listing ON public.contact_requests USING btree (listing_id);

CREATE INDEX idx_contact_status ON public.contact_requests USING btree (status, created_at);

CREATE INDEX idx_events_listing ON public.events USING btree (listing_id);

CREATE INDEX idx_events_type_time ON public.events USING btree (event_type, created_at DESC);

CREATE INDEX idx_listings_browse ON public.listings USING btree (status, city_id, area_id, price);

CREATE INDEX idx_listings_expiry ON public.listings USING btree (status, expires_at);

CREATE INDEX idx_listings_owner ON public.listings USING btree (owner_id);

CREATE INDEX idx_listings_published ON public.listings USING btree (status, area_id, price)
  WHERE (status = 'published'::public.listing_status);

CREATE INDEX idx_profiles_phone ON public.profiles USING btree (phone);

CREATE INDEX idx_profiles_role ON public.profiles USING btree (ROLE);

CREATE INDEX idx_vlog_subject ON public.verification_log USING btree (subject_type, subject_id);

CREATE UNIQUE INDEX listings_confirm_token_key ON public.listings USING btree (confirm_token);

CREATE UNIQUE INDEX uq_contact_once ON public.contact_requests USING btree (listing_id, seeker_phone);

CREATE TRIGGER trg_contact_rented
  BEFORE UPDATE ON public.contact_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.on_contact_rented();

CREATE TRIGGER trg_block_camera
  AFTER INSERT OR UPDATE ON public.listing_safety
  FOR EACH ROW
  EXECUTE FUNCTION public.block_camera_listings();

CREATE TRIGGER trg_force_pending
  BEFORE INSERT ON public.listings
  FOR EACH ROW
  EXECUTE FUNCTION public.force_pending_on_insert();

CREATE TRIGGER trg_listing_publish
  BEFORE UPDATE ON public.listings
  FOR EACH ROW
  EXECUTE FUNCTION public.on_listing_publish();

CREATE TRIGGER trg_listing_ref
  BEFORE INSERT ON public.listings
  FOR EACH ROW
  EXECUTE FUNCTION public.set_listing_ref();

CREATE TRIGGER trg_fee_due
  BEFORE INSERT OR UPDATE ON public.owner_fees
  FOR EACH ROW
  EXECUTE FUNCTION public.compute_fee_due();

CREATE TRIGGER trg_report_suspend
  AFTER INSERT ON public.reports
  FOR EACH ROW
  EXECUTE FUNCTION public.suspend_on_serious_report();

CREATE TRIGGER trg_reviews_threshold
  AFTER INSERT ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.publish_reviews_at_threshold();

CREATE TRIGGER trg_request_ref
  BEFORE INSERT ON public.seeker_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.set_request_ref();

CREATE POLICY "anon_insert_contact" ON "public"."contact_requests"
  FOR INSERT
  TO "anon", "authenticated"
  WITH CHECK (((status = 'new'::public.contact_status) AND (agent_id IS NULL) AND (agent_notes IS NULL) AND (outcome_source IS NULL) AND (outcome_at IS NULL) AND (seeker_phone IS
    NOT NULL) AND ((length(btrim(seeker_phone)) >= 9) AND (length(btrim(seeker_phone)) <= 20)) AND ((listing_id IS NOT NULL) OR (request_id IS NOT NULL))));

CREATE POLICY "anon_insert_event" ON "public"."events"
  FOR INSERT
  TO "anon"
  WITH CHECK ((source = 'user'::public.event_source));

CREATE POLICY "anon_insert_report" ON "public"."reports"
  FOR INSERT
  TO "anon"
  WITH CHECK (true);

CREATE EVENT TRIGGER "ensure_rls"
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION "public"."rls_auto_enable"();

COMMENT ON COLUMN "public"."listings"."confirm_token" IS 'رمز سري بالرابط اللي بينبعت للمالك بالواتساب. بدونه ما بينعمل تمديد.';

COMMENT ON EXTENSION "pg_cron" IS 'Job scheduler for PostgreSQL';

GRANT EXECUTE ON FUNCTION "public"."block_camera_listings"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."compute_fee_due"() TO PUBLIC, "postgres";

REVOKE ALL ON FUNCTION "public"."confirm_listing_available"(text, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."confirm_listing_available"(text, uuid) TO "anon", "authenticated", "postgres";

GRANT EXECUTE ON FUNCTION "public"."expire_stale_listings"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."force_pending_on_insert"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_field_verified"(uuid) TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."on_contact_rented"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."on_listing_publish"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."publish_reviews_at_threshold"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO PUBLIC, "postgres";

GRANT EXECUTE
  ON FUNCTION "public"."sakan_match_score"(integer[], numeric, public.gender_type, public.listing_kind, date, integer, numeric, public.gender_policy, public.listing_kind, date)
  TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_listing_ref"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_request_ref"() TO PUBLIC, "postgres";

GRANT EXECUTE ON FUNCTION "public"."submit_listing"(text, text, text, integer, numeric, text, text, boolean, date, text, text, text) TO PUBLIC, "anon", "postgres";

GRANT EXECUTE ON FUNCTION "public"."submit_request"(text, text, text, text, numeric, integer[], date, text[], text) TO PUBLIC, "anon", "postgres";

GRANT EXECUTE ON FUNCTION "public"."suspend_on_serious_report"() TO PUBLIC, "postgres";

GRANT SELECT, USAGE ON SEQUENCE "public"."areas_id_seq" TO "anon";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."areas_id_seq" TO "postgres";

GRANT SELECT, USAGE ON SEQUENCE "public"."cities_id_seq" TO "anon";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."cities_id_seq" TO "postgres";

GRANT SELECT, USAGE ON SEQUENCE "public"."events_id_seq" TO "anon";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."events_id_seq" TO "postgres";

GRANT SELECT, USAGE ON SEQUENCE "public"."listing_ref_seq" TO "anon";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."listing_ref_seq" TO "postgres";

GRANT SELECT, USAGE ON SEQUENCE "public"."request_ref_seq" TO "anon";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."request_ref_seq" TO "postgres";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."areas" TO "anon";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."areas" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."areas" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."areas" TO "service_role";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."cities" TO "anon";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."cities" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."cities" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."cities" TO "service_role";

GRANT INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."contact_requests" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."contact_requests" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."contact_requests" TO "service_role";

GRANT INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."events" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."events" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."events" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."listing_safety" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."listing_safety" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."listing_safety" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."listings" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."listings" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."listings" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."owner_fees" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."owner_fees" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."owner_fees" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."profiles" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."profiles" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."promo_codes" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."promo_codes" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."promo_codes" TO "service_role";

GRANT INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."reports" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reports" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."reports" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."reviews" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reviews" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."reviews" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."seeker_requests" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."seeker_requests" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."seeker_requests" TO "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."verification_log" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."verification_log" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."verification_log" TO "service_role";

GRANT USAGE ON TYPE "public"."contact_status" TO "postgres";

GRANT USAGE ON TYPE "public"."event_source" TO "postgres";

GRANT USAGE ON TYPE "public"."fee_status" TO "postgres";

GRANT USAGE ON TYPE "public"."gender_policy" TO "postgres";

GRANT USAGE ON TYPE "public"."gender_type" TO "postgres";

GRANT USAGE ON TYPE "public"."listing_kind" TO "postgres";

GRANT USAGE ON TYPE "public"."listing_status" TO "postgres";

GRANT USAGE ON TYPE "public"."listing_verification" TO "postgres";

GRANT USAGE ON TYPE "public"."occupation_type" TO "postgres";

GRANT USAGE ON TYPE "public"."report_category" TO "postgres";

GRANT USAGE ON TYPE "public"."report_status" TO "postgres";

GRANT USAGE ON TYPE "public"."request_status" TO "postgres";

GRANT USAGE ON TYPE "public"."review_stage" TO "postgres";

GRANT USAGE ON TYPE "public"."user_role" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."v_kpi_core" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."v_kpi_core" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."v_kpi_quality" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."v_kpi_quality" TO "service_role";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."v_listings_public" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."v_listings_public" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."v_listings_public" TO "service_role";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."v_requests_public" TO "anon", "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."v_requests_public" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."v_requests_public" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."v_reverse_matches" TO "postgres";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."v_reverse_matches" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLES TO "service_role";

SELECT cron.schedule_in_database('expire-stale', '5 3 * * *', ' select expire_stale_listings(); ', 'postgres', NULL, true);

