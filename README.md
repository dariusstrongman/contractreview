# ContractReview

`$5` AI red-flag scanner for contracts. Upload PDF or paste text, get back structured review (critical / negotiate / looks-fine / questions) with a 0-100 risk score. Built for the person being asked to sign — not for B2B legal teams.

Live at: **https://contract.stromation.com**

## Stack

- **Frontend:** Static HTML/CSS/JS, GitHub Pages, brand palette is rose-red on white (differs from PolicyBot's indigo). Same `Instrument Serif + Source Sans 3` typography as PolicyBot for visual coherence.
- **Backend:** n8n workflow at `n8n.stromation.com` handles checkout / fulfill / status modes on a single webhook.
- **Payments:** Stripe live mode (one-time $5 checkout).
- **AI:** GPT-4o for the analysis pass, returns strict JSON schema.
- **DB:** Supabase table `contractreview_jobs` stores form data + extracted contract text, keyed by Stripe session_id.

## Setup checklist (one-time)

### 1. DNS
Add a CNAME in Hostinger:

```
Type:   CNAME
Name:   contract
Value:  dariusstrongman.github.io
TTL:    14400
```

Wait for `dig +short contract.stromation.com` to return the GitHub Pages IPs (~5-15 min).

### 2. GitHub Pages
- Repo settings → Pages → Source: `main` / root
- Custom domain: `contract.stromation.com`
- Enforce HTTPS (after first deploy)

### 3. Supabase schema
Open the SQL editor at `iadzcnzgbtuigyodeqas.supabase.co` and run:

```sql
-- contents of sql/schema.sql
```

This creates the `contractreview_jobs` table with RLS enabled (`USING (true)` — service-key writes only).

### 4. n8n workflow
Already created via API. Workflow name: `ContractReview - Generate & Deliver`. Single webhook at `/webhook/contract-review` handles all three modes:
- `mode=checkout` (POST with form fields) → returns `{checkout_url, session_id}`
- `mode=fulfill` (GET ?session_id=X) → verifies Stripe payment, runs GPT-4o analysis, stores review, sends email, returns `{status: 'ready', review: {...}}`
- `mode=status` (GET ?session_id=X) → returns cached review without re-running AI

### 5. Email sender (optional but recommended)
The fulfill mode tries to POST the rendered email to `https://n8n.stromation.com/webhook/contract-review-email`. Clone PolicyBot's `Email Sender` workflow:
- Copy `PolicyBot - Email Sender` (workflow ID `RcJVlfV7VP8hayqG`)
- Rename to `ContractReview - Email Sender`
- Change webhook path to `contract-review-email`
- Activate

If you skip this, the review still lands in the success page UI and stays in Supabase — it just won't email.

### 6. Stripe
Live key is already embedded in the n8n workflow code node (same key as PolicyBot uses). No Stripe webhook needed — the success page calls fulfill which verifies payment by hitting Stripe's API directly. To rotate the key, edit it in the n8n workflow `STRIPE_KEY` constant (don't commit keys to git).

## Architecture

```
contract.stromation.com (GitHub Pages)
   │
   ├── index.html ────POST form (mode=checkout)──┐
   │                                              │
   │                                              ▼
   │                  n8n: /webhook/contract-review
   │                       │
   │                       ├─ insert contractreview_jobs (status=pending)
   │                       ├─ create Stripe checkout session
   │                       ├─ stamp session_id on row
   │                       └─ return checkout_url
   │                                              │
   ├── (Stripe redirects) ◄──────────────────────┘
   │
   ├── success.html?session_id=X
   │                       │
   │                       └─ GET fulfill ─────► n8n: /webhook/contract-review
   │                                                  │
   │                                                  ├─ verify Stripe payment
   │                                                  ├─ load contractreview_jobs row
   │                                                  ├─ GPT-4o analysis (JSON output)
   │                                                  ├─ store review_json, status=ready
   │                                                  ├─ POST email-sender webhook
   │                                                  └─ return review
   │                                                  │
   │                       ◄──────────────────────────┘
   │                       └─ render score + flags + questions

   sql/schema.sql ────► contractreview_jobs in Supabase
```

## File layout

```
contractreview/
├── CNAME                       # contract.stromation.com
├── .nojekyll                   # disable Jekyll on GH Pages
├── robots.txt
├── sitemap.xml
├── feed.xml                    # RSS for the blog
├── index.html                  # main landing + form
├── success.html                # post-payment review delivery
├── disclaimer.html             # full legal disclaimer
├── blog.html                   # blog index (auto-publisher will fill)
├── sql/
│   └── schema.sql              # Supabase migration
└── README.md
```

## Pricing & unit economics

- Price: `$5` one-time
- Stripe fee: ~$0.45
- OpenAI cost (GPT-4o, ~5K input tokens average + 800 output): ~$0.04
- Supabase + GH Pages + n8n: shared with other Stromation products, marginal cost ~$0.01
- **Net per sale: ~$4.45**

## Disclaimer footprint

Same multi-touchpoint pattern as PolicyBot to minimize liability:
1. Hero banner: "Templates only — not legal advice"
2. Required consent checkbox in form (HTML5 + JS validation)
3. Persistent reminder on success page
4. Footer link in every page
5. `/disclaimer.html` is indexed in sitemap → searchable record

## Known limitations / TODO

- **PDF upload not yet implemented.** v1 is paste-text only. To add PDF: in the n8n workflow, accept multipart, extract text via OpenAI's file API or pdftotext, then run analysis. Frontend already has the upload tab UI.
- **No customer dashboard.** Repeat customers email contact@ to retrieve old reviews.
- **No automated blog yet.** Clone PolicyBot's `Auto Blog Publisher` workflow, point at this repo, and it'll start filling `/blog/`.
- **Email retry.** If the email-sender webhook is down, the review is still cached in Supabase but no email is sent. Consider a daily reconciliation job.
- **PDF output of review.** Currently HTML only. Add PDF generation via LibreOffice (same pattern as PolicyBot's `htmlToPdfB64`) for a "Download Review" button on the success page.

## Legal cover

`/disclaimer.html` lists the situations where the user MUST consult an attorney:
- Real estate purchase / mortgage / multi-year commercial lease
- Employment with equity / RSUs / executive comp
- Partnership / co-founder / operating agreements
- M&A, fundraising, major investment
- Healthcare, finance, regulated industries
- High-stakes litigation potential

Required consent checkbox makes the user explicitly acknowledge before payment.
