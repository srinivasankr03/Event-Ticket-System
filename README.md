# UtsavPass: Event Discovery & Ticket Reservation System

A full-stack web app where people can discover events, hold tickets for 10 minutes, and confirm their booking. Signed-in users can also host their own events.

**Live demo:** https://srinivasankr03.github.io/Event-Ticket-System/

---

## 1. Problem Statement

When many people try to book the last few tickets for an event at the same time, a simple website can sell the same ticket twice (double booking). UtsavPass solves this by doing the booking checks **inside the database**, so the server decides who gets the ticket, not the browser.

## 2. Features

- Browse events with search and category filters (Music, Business, Food & Drink, Gaming, Technology)
- Live count of tickets left for every event
- Sign up and sign in with email and password (email confirmation supported)
- **Reserve tickets** (1 to 6 per booking). The tickets are held for **10 minutes**.
- **Confirm** the booking within the hold time, or **cancel** it
- Expired holds are released automatically and the tickets become available again
- **My tickets** page showing a user's own reservations
- **Host an event** (title, category, venue, date and time, price, capacity, description)
- Prices in Indian Rupees (₹)

## 3. Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML, CSS, JavaScript (single page, `index.html`) |
| Backend | Supabase (PostgreSQL database, Supabase Auth, SQL functions) |
| Client library | `supabase-js` v2 (loaded from a CDN) |
| Hosting | GitHub Pages or Vercel (static hosting for the frontend) |

## 4. Architecture

```
 Browser (index.html + config.js)
        |
        |  HTTPS, Supabase API
        v
 Supabase (cloud backend)
   - Auth: sign up, sign in, sessions
   - PostgreSQL: events, reservations
   - SQL functions: reserve / confirm / cancel / availability
   - Row Level Security: who can see or change what
```

The website is only the user interface. All data and business rules live in Supabase.

## 5. Database Design

### `events`
| Column | Type | Notes |
|---|---|---|
| id | bigint | Primary key, auto generated |
| title | text | Required |
| category | text | Required |
| venue | text | |
| starts_at | timestamptz | Required |
| price | int | Default 0 |
| capacity | int | Must be greater than 0 |
| description | text | |
| icon | text | Emoji shown on the card |
| created_by | uuid | The user who hosted the event |

### `reservations`
| Column | Type | Notes |
|---|---|---|
| id | bigint | Primary key, auto generated |
| event_id | bigint | Foreign key to `events` (deleted with the event) |
| user_id | uuid | The user who booked |
| qty | int | Between 1 and 6 |
| status | text | `held`, `confirmed` or `cancelled` |
| expires_at | timestamptz | When a hold expires |

**Relationship:** one event has many reservations, and one user has many reservations.

## 6. Backend Logic (SQL Functions)

| Function | What it does |
|---|---|
| `reserve_tickets(event, qty)` | Requires login. Locks the event row, counts confirmed and active holds, checks that enough tickets remain, then creates a `held` reservation valid for 10 minutes. |
| `confirm_reservation(id)` | Changes a hold to `confirmed`, but only for the owner and only if the hold has not expired. |
| `cancel_reservation(id)` | Cancels a held or confirmed reservation owned by the user. |
| `event_availability()` | Returns tickets left for each event. Expired holds are not counted. |

**Why no double booking?** `reserve_tickets` locks the event row (`FOR UPDATE`) while it checks capacity. If two people try to book the last ticket at the same moment, the database processes them one after another, so only one succeeds.

## 7. Security

- **Row Level Security (RLS)** is enabled on both tables.
- Anyone can view events.
- Only signed-in users can host events, and only under their own account.
- Users can only see their own reservations.
- Reservations cannot be inserted or updated directly. Everything goes through the SQL functions above.
- Passwords are stored encrypted by Supabase Auth.
- Only the **publishable (anon) key** is used in the website, and it is safe to be public because RLS protects the data. The **secret key must never be added to this project.**

## 8. Project Files

```
index.html    The whole frontend (UI + logic)
config.js     Supabase URL and publishable key
schema.sql    Database tables, security rules, functions and sample events
vercel.json   Hosting configuration (clean URLs)
README.md     This file
```

## 9. Setup Guide

### Step 1: Create the backend (Supabase)
1. Create a free project at https://supabase.com
2. Open **SQL Editor → New query**, paste the full contents of `schema.sql`, and click **Run**. Run it **only once**. Running it again gives the harmless error "relation already exists".
3. Go to **Project Settings → API** and copy the **Project URL** and the **publishable (anon) key**.

### Step 2: Configure the frontend
Edit `config.js`:

```js
window.UTSAV_CONFIG = {
  url: "https://YOUR-PROJECT-ID.supabase.co",
  key: "YOUR-PUBLISHABLE-KEY"
};
```

### Step 3: Set up authentication
In Supabase, go to **Authentication → URL Configuration** and set:
- **Site URL:** your live website address
- **Redirect URLs:** your website address followed by `/**`

Optional for testing: turn off **Confirm email** under **Authentication → Sign In / Providers → Email**.

### Step 4: Host the website
**GitHub Pages:** Repository → Settings → Pages → deploy from the `main` branch.

**Vercel:** Sign in with GitHub → Add New Project → import the repository → Deploy. No build settings are needed.

## 10. How to Demo

1. Open the live site and show the event list and filters.
2. Create an account and sign in.
3. Click **Host an event**, create one, and show it appear on the home page.
4. Reserve tickets and show the 10-minute hold.
5. Confirm the booking, then open **My tickets**.
6. In Supabase, show the `events` and `reservations` tables in **Table Editor**, the users in **Authentication**, and the rules in **Policies**.

## 11. Known Limitations

- No real payment gateway (booking is confirmed without payment).
- Supabase's free built-in email sending is limited to a few emails per hour.
- No QR code tickets or email receipts.
- Expired holds are ignored when counting availability, but their rows are not deleted.

## 12. Future Improvements

- Payment integration (Razorpay or UPI)
- QR code tickets and email receipts
- Organizer dashboard with attendee lists
- Event images and editing or deleting events
- Admin role and multiple organizations

## 13. Author

Built by **[Your Name]** as a college project.
