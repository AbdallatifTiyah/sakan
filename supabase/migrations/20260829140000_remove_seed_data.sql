-- One-time removal of pre-launch seed data.
-- Idempotent: safe to re-run, and a no-op on a fresh database.
-- Preserves cities, areas and promo_codes — those are real data.

begin;

-- Child rows first: every table below points at listings, profiles
-- or seeker_requests, so they must go before their parents.
delete from events;
delete from owner_fees;
delete from reviews;
delete from reports;
delete from verification_log;
delete from contact_requests;
delete from listing_safety;

-- Parents, innermost last.
delete from seeker_requests;
delete from listings;
delete from profiles;

-- Reset counters so the first real listing is SK-1000, not SK-1002.
alter sequence listing_ref_seq restart with 1000;
alter sequence request_ref_seq restart with 500;
alter sequence events_id_seq   restart with 1;

commit;
