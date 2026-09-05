create or replace view v_admin_owners as
 SELECT p.id,
    p.first_name,
    p.full_name,
    p.phone,
    p.verification_level,
    p.is_blocked,
    p.created_at,
    p.city_id,
    c.name_ar AS city,
    ( SELECT count(*) AS count
           FROM listings l
          WHERE l.owner_id = p.id) AS listings_total,
    ( SELECT count(*) AS count
           FROM listings l
          WHERE l.owner_id = p.id AND l.status = 'published'::listing_status) AS listings_published,
    ( SELECT count(*) AS count
           FROM listings l
          WHERE l.owner_id = p.id AND l.status = 'pending'::listing_status) AS listings_pending,
    ( SELECT count(*) AS count
           FROM listings l
          WHERE l.owner_id = p.id AND l.status = 'rented'::listing_status) AS listings_rented,
    ( SELECT max(l.created_at) AS max
           FROM listings l
          WHERE l.owner_id = p.id) AS last_listing_at,
    ( SELECT COALESCE(sum(f.amount_due), 0::numeric) AS "coalesce"
           FROM owner_fees f
             JOIN listings l ON l.id = f.listing_id
          WHERE l.owner_id = p.id AND f.status = 'due'::fee_status) AS fees_due,
    ( SELECT COALESCE(sum(f.amount_due), 0::numeric) AS "coalesce"
           FROM owner_fees f
             JOIN listings l ON l.id = f.listing_id
          WHERE l.owner_id = p.id AND f.status = 'collected'::fee_status) AS fees_collected,
    ( SELECT count(*) AS count
           FROM reports r
             JOIN listings l ON l.id = r.listing_id
          WHERE l.owner_id = p.id) AS reports_total,
    p.owner_token,
    (p.account_uid is not null) as has_account
   FROM profiles p
     LEFT JOIN cities c ON c.id = p.city_id
  WHERE p.role = 'owner'::user_role;

create or replace view v_admin_seekers as
 SELECT p.id,
    p.first_name,
    p.full_name,
    p.phone,
    p.gender,
    p.occupation,
    p.org_name,
    p.verification_level,
    p.verified_at,
    p.is_blocked,
    p.created_at,
    c.name_ar AS city,
    ( SELECT count(*) AS count
           FROM seeker_requests r
          WHERE r.seeker_id = p.id) AS requests_total,
    ( SELECT count(*) AS count
           FROM seeker_requests r
          WHERE r.seeker_id = p.id AND r.status = 'published'::request_status) AS requests_active,
    ( SELECT count(*) AS count
           FROM contact_requests cr
          WHERE cr.seeker_id = p.id) AS contacts_total,
    ( SELECT count(*) AS count
           FROM contact_requests cr
          WHERE cr.seeker_id = p.id AND cr.status = 'rented'::contact_status) AS rentals,
    (p.account_uid is not null) as has_account
   FROM profiles p
     LEFT JOIN cities c ON c.id = p.city_id
  WHERE p.role = 'seeker'::user_role;
