# Clinic Stakeholder knowledge

## Participant brief

PetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application.

## Fixed facts

- The chatbot is staff-facing and read-only.
- The Clinic Assistant must never claim to change PetClinic data.
- Answers must come only from retrieved PetClinic records.
- The chatbot must admit when records are absent or a request is unsupported.
- The chatbot must not provide veterinary diagnosis or treatment advice.
- The capability families are owner and pet lookup, Visit summaries, and veterinarian specialties.
- When multiple records match, the chatbot presents candidates and asks a clarifying question.
- The chatbot must not guess identity.
- Staff need an accessible chat option.
- Keep a concise, visible activity trace of tool calls and their outcomes.

## Available preferences

- Prefer the smallest evidence-producing vertical slice.
- Prefer comparable engineering evidence over identical implementations.

## Explicit unknowns

- The exact UI surface and navigation treatment are unresolved.
- The first capability family is unresolved.
- Exact wording, visual design, and conversational tone are unresolved.
- The bounded assumptions accepted at the Commitment Gate are unresolved until the human records them.
- Production authentication, authorization, privacy controls, auditing, prompt-injection hardening, production observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved.

Unresolved or out-of-slice items must not become invented requirements.
