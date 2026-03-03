---
marp: true
title: Intro workshop - GitOps in de praktijk
paginate: true
---

# GitOps in de praktijk

Korte intro (5 min)

---

## Doel van vandaag

- Een werkende GitOps-loop bouwen op lokale k3s
- Begrijpen waarom dit patroon productie-relevant is
- Eindigen met een reproduceerbare setup

---

## Agenda

1. VM + k3s klaarzetten
2. ArgoCD en app-of-apps
3. Ingress + MetalLB
4. Tekton pipeline
5. Bonus: monitoring

---

## Wat je leert

- Git als bron van waarheid
- Drift detectie en self-heal
- Samenhang tussen CI (Tekton) en CD (ArgoCD)
- Grenzen van een workshop-opzet

---

## Werkafspraak

- Kleine stappen
- Steeds verifiëren
- Problemen eerst observeren, dan repareren

---

# Klaar om te starten

Eerst baseline werkend, daarna optimaliseren.
