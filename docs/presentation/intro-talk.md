# Intro talk (5 minuten)

## Opening

Welkom. In deze workshop bouwen we een kleine maar complete GitOps-keten op een lokale Kubernetes-VM.

Doel: niet alleen "iets werkend krijgen", maar snappen waarom dit patroon in echte omgevingen werkt.

## Wat we gaan doen

1. Een k3s-cluster opzetten in Vagrant.
2. ArgoCD installeren en een app-of-apps structuur gebruiken.
3. Networking toevoegen (Ingress + MetalLB) zodat apps bereikbaar zijn.
4. Een Tekton pipeline draaien die een wijziging naar Git terugschrijft.
5. (Bonus) Monitoring bekijken.

## Wat je onderweg leert

- Waarom "Git als bron van waarheid" nuttig is.
- Hoe ArgoCD drift detecteert en herstelt.
- Hoe CI (Tekton) en CD (ArgoCD) op elkaar aansluiten.
- Welke workshopkeuzes je in productie anders zou doen.

## Verwachting voor vandaag

Aan het eind heb je:

- Een reproduceerbaar lokaal platform-opzet.
- Begrip van de GitOps-loop van commit tot running workload.
- Een basis om dit patroon later uit te breiden naar meerdere clusters.

## Praktisch

- We werken met korte stappen en veel verificatie.
- Als iets niet meteen werkt: eerst status checken, dan pas fixen.
- Onthoud: fouten in deze workshop zijn juist nuttig, ze laten zien hoe het systeem reageert.
