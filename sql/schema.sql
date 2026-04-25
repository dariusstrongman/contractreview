-- Run in the Stromation Supabase SQL editor.
-- Same project as ResumeGo / PolicyBot / Clipper / TBE.

CREATE TABLE IF NOT EXISTS contractreview_jobs (
    id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id      text UNIQUE,                      -- Stripe checkout session id (set at checkout creation)
    contract_type   text,                              -- lease | employment | nda | freelance | saas | partnership | service | other
    role            text,                              -- renter | employee | contractor | client | vendor | etc.
    jurisdiction    text,                              -- "California", "UK", etc.
    context         text,                              -- free-text user notes
    email           text NOT NULL,
    contract_text   text,                              -- extracted or pasted contract body
    contract_filename text,
    review_json     jsonb,                             -- final structured review (risk_score, critical[], negotiate[], looks_fine[], questions[])
    status          text DEFAULT 'pending',            -- pending | paid | ready | failed
    error           text,
    created_at      timestamptz DEFAULT now(),
    paid_at         timestamptz,
    delivered_at    timestamptz
);
CREATE INDEX IF NOT EXISTS contractreview_jobs_session_idx ON contractreview_jobs (session_id);
CREATE INDEX IF NOT EXISTS contractreview_jobs_status_idx ON contractreview_jobs (status, created_at DESC);

ALTER TABLE contractreview_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "contractreview_service" ON contractreview_jobs;
CREATE POLICY "contractreview_service" ON contractreview_jobs FOR ALL USING (true) WITH CHECK (true);
