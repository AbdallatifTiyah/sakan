update public.cities set name_en = v.name_en from (values
  ('ramallah','Ramallah & Al-Bireh'),
  ('birzeit','Birzeit'),
  ('nablus','Nablus'),
  ('bethlehem','Bethlehem'),
  ('hebron','Hebron')
) as v(slug, name_en) where cities.slug = v.slug;

update public.areas set name_en = v.name_en from (values
  ('masyoun','Al-Masyoun'),
  ('tireh','Al-Tireh'),
  ('um-al-sharayet','Um Al-Sharayet'),
  ('ein-misbah','Ein Misbah'),
  ('baloa','Al-Balou'''),
  ('beitunia','Beitunia'),
  ('irsal','Al-Irsal'),
  ('downtown','Downtown Ramallah'),
  ('bireh-industrial','Al-Bireh — Industrial Area'),
  ('surda','Surda'),
  ('birzeit-center','Birzeit Center'),
  ('near-campus','Near the University'),
  ('abu-qash','Abu Qash')
) as v(slug, name_en) where areas.slug = v.slug;

update public.pages set title_en = 'How Sakan Works', body_en = $body$
Last updated: September 1, 2026

## In short

Sakan is a platform that connects room owners with people looking for housing in Ramallah, Al-Bireh, and Birzeit. Every listing is verified before publishing, and phone numbers are always protected.

---

## If you're looking for a place

1. **Browse listings** without registering or creating an account — filter by city, area, price, and type, and search listings by title and description.
2. **Open any listing** to see full details: price, features, field-visit results if any, and photos of the room.
3. **Leave your name and number** with the "Send contact request" button — we only share your number with the owner after you agree to send the request.
4. **We reach out within 24 hours** to connect you with the owner.

**Completely free** during the launch period. There are no fees for people looking for housing.

Didn't find a room that fits? Register your request under the "Looking for housing" tab and we'll notify you as soon as a matching room is listed.

---

## If you have a room to rent

1. **Register the listing** with the "List a room" button — details, photos (up to 6), and price.
2. **We reach out within 24 hours** for phone verification before publishing.
3. **The listing goes live** after verification, and stays active for 21 days — after that you'll need to confirm it's still available through a link we send you, or it expires automatically.
4. **Once it's rented through the platform**, you pay a one-time success fee, collected in cash by our agent. The amount is shown at registration and doesn't change after the agreement.

Full details are on the **Terms of Use** page.

---

## Verification levels

| Level | What it means |
|---|---|
| **Phone-verified** | We spoke with the owner and confirmed they exist and the listing is real |
| **Field-verified** | Our agent visited the place in person and checked specific items (door lock, photos match, number of occupants, and more) |

Field-visit notes describe the place's condition on the day of the visit, not a permanent guarantee. If you notice anything different after the visit, report it immediately.

---

## Privacy in one line

Your phone number and exact address **never appear on the site** — not to seekers, not to search engines. Full details are on the **Privacy Policy** page.

---

## Safety and reports

Sakan **is not a party to the rental agreement** — we verify and connect, and the agreement is between you and the other party. If something goes wrong — before or after renting — submit a report via "Contact us or file a report" at the bottom of any page. Serious reports (like harassment or entering the room without permission) automatically suspend the listing pending review.

The platform **is not a monitoring tool**. We don't give anyone — not family, not the owner — a way to track a resident.

---

## FAQ

**Is there an app?**
No, the site works directly from your browser, with no login required for seekers or owners.

**Is there in-site chat?**
No. Communication happens over WhatsApp after we connect both sides.

**What if the listing expired and I'm still interested?**
Contact us and we'll check with the owner whether the room is still available.
$body$ where key = 'how-it-works';

update public.pages set title_en = 'Privacy Policy', body_en = $body$
Last updated: August 31, 2026

## In short

Sakan is a platform that connects room owners with people looking for housing in Ramallah, Al-Bireh, and Birzeit.

For the platform to work, we need to collect some information from you. This page tells you exactly what we collect, why, and who sees it.

**Three rules we never break:**

1. **Your phone number is never shown on the site** — not to seekers, not to owners, not to search engines.
2. **The exact address is never shown** — we only show the area and a nearby landmark.
3. **We never sell or rent out your data to anyone.**

---

## 1. Who we are

Sakan — a platform for verified room rentals and shared housing, operating in Ramallah, Al-Bireh, and Birzeit.

To reach us with any question about your privacy or to request deletion of your data, use the "Contact us or file a report" form at the bottom of any page and choose "General inquiry."

---

## 2. What we collect

### If you list a room

- Your first name and WhatsApp number
- Room details: address, description, price, deposit, area, type, features, availability date
- The nearby landmark, and the exact address if you gave it to us for a field visit
- Our agent's notes after the visit, if one happened

### If you register a housing request

- Your first name and WhatsApp number
- Gender, occupation (student/employee/other), budget, preferred city and areas, move-in date, your traits as a resident, and any notes you wrote

### If you send a contact request or a report

- Your name and number (the number is optional for reports)
- The report text and its category

### Automatically

The site **does not use cookies, tracking tools, or analytics**. We use an Arabic font hosted by Google Fonts, which means Google sees your IP address when the page loads — this is the only thing that goes to a third party, and we can't control it except by removing the font.

---

## 3. What's shown publicly

| Shown | Not shown |
|---|---|
| Your first name only | Your full name |
| City and area | Exact address |
| Price and features | Your phone number |
| Your traits as a resident and notes | Your workplace or school |
| Field-visit result | Internal agent notes |

---

## 4. Why we use your number

- To call you for verification before publishing your listing
- To connect you with the other party when there's genuine interest, **and after you know a contact request exists**
- To remind you to confirm your listing is still available every 21 days
- To get back to you with the outcome of your report if you left your number

**We never send you marketing messages you didn't ask for.**

---

## 5. Who sees your data

- **You.**
- **The Sakan team**: staff and field agents, strictly within the scope of their work. Every action is logged under the name of who did it.
- **The other party in the deal**: when you send a contact request, we give the owner your name and number. That's the purpose of the request.
- **Official authorities**: if legally required, or if there's an immediate risk to someone's safety.

Our servers are hosted with Supabase in Frankfurt, Germany, and the site is served through Cloudflare. These are technical providers that process data on our behalf and don't use it for their own purposes.

---

## 6. How long we keep data

- **Listings**: expire automatically after 21 days unless the owner confirms they're still available
- **Housing requests**: expire on the same schedule after publishing
- **Owner or seeker profile**: stays on file so we know the history of the relationship and prevent repeat problems
- **Reports and action logs**: kept on file — these are safety records

You can request deletion of your profile at any time.

---

## 7. Your rights

- **See** what's stored about you
- **Correct** any wrong information
- **Delete** your profile, listings, and requests
- **Withdraw consent** and stop being contacted

Request any of these through the contact form. We respond within 14 days.

**One exception**: reports tied to another person's safety can't be deleted, but we can anonymize your identity from them.

---

## 8. Security

- All traffic to the site is encrypted (HTTPS)
- Phone numbers and exact addresses are blocked at the database level itself, not just in the interface — meaning even if there's a bug in the site, they still won't be exposed
- The admin panel is protected and only accessible to the Sakan team
- Every administrative action is logged with who did it and when

No system is 100% secure. If a breach affects your data, we will let you know.

---

## 9. Safety — the limits of our role

Sakan **is not a party to the rental agreement**. We verify and connect, and the agreement is between you and the other party.

We use two verification levels:
- **Phone-verified**: we spoke with the owner and confirmed they exist and the listing is real
- **Field-verified**: our agent visited the place and checked specific items

**Visit notes describe the place's condition on the day of the visit, not a permanent guarantee.** If you notice anything different, report it immediately.

The platform **is not a monitoring tool**. We don't give anyone — not family, not the owner — a way to track a resident.

---

## 10. Age

The platform is for adults (18 and older). We don't knowingly collect data from children. If we discover someone under 18 registered, we delete their data.

---

## 11. Changes to this policy

When we make a material change, we update the date at the top. Continuing to use the platform after a change means you accept it.
$body$ where key = 'privacy';

update public.pages set title_en = 'Terms of Use', body_en = $body$
Last updated: August 31, 2026

## 1. Nature of the service

Sakan is a matchmaking and verification platform. **We are not a party to the rental agreement** and are not responsible for disputes between owner and tenant.

## 2. Your obligations

**If you're an owner:**
- Listing information must be accurate and current
- Photos must be of the actual room
- Confirm the listing is still available every 21 days, or it expires automatically
- You agree to pay the success fee once the rental is completed through the platform

**If you're a seeker:**
- Your information must be accurate
- You won't use contact details for anything other than housing purposes

## 3. Prohibited

Fake listings · impersonation · harassment · discrimination in violation of the law · collecting other users' data · any use that violates Palestinian law.

Violating any of these terms means your account and listings may be suspended without notice.

## 4. Fees

- **Housing seekers: free.**
- **Owners: a one-time success fee** when the rental is completed through the platform, collected in cash by our agent. The amount is shown at registration.

## 5. Safety and reports

Any safety report is reviewed. Serious reports automatically suspend the listing pending review.

## 6. Limitation of liability

We make reasonable efforts to verify, but we don't guarantee the condition of the housing or the conduct of any party. The final decision on viewing and signing is your responsibility.

## 7. Governing law

Palestinian law applies, and the courts of Ramallah have jurisdiction over any dispute.
$body$ where key = 'terms';
