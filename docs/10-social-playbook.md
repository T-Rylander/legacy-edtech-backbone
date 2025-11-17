# Social Media Playbook

## LinkedIn Content Strategy

### Carousel Post Template: "From Potato CPU to Pipeline"

**Slide 1**: Hook
- "How we deployed 50 school laptops in one afternoon"
- "Zero-touch imaging with $500 in repurposed gear"

**Slide 2**: The Problem
- Manual Windows installs: 2 hours per device
- Domain joins: another 30 minutes each
- Total: 100+ hours for a 50-device lab

**Slide 3**: The Solution
- PXE network boot from Z390 ($200 refurb)
- Samba AD for authentication
- Golden WIM with auto-join scripts

**Slide 4**: The Results
- Deploy time: <30 minutes per device
- Walk away while imaging happens
- Centralized auth for all users

**Slide 5**: Tech Stack
- Ubuntu 24.04 LTS + Samba
- dnsmasq PXE proxy
- UniFi network infrastructure
- Open-source, fork-friendly

**Slide 6**: Call to Action
- "Fork the repo: github.com/T-Rylander/legacy-edtech-backbone"
- "DM for questions on repurposed edtech stacks"

### Twitter/X Thread Hooks

**Thread 1**: Hardware Journey
```
1/ Built an edtech IT stack for <$1000
- Z390 workstation as AD DC
- Pi 5 for helpdesk
- UniFi gear for network
- Zero cloud costs 🧵👇

2/ Why repurposed hardware?
- Schools have tight budgets
- Validate demand before scaling
- Learn Linux admin hands-on
- No vendor lock-in

[Continue with 8-10 tweets]
```

**Thread 2**: PXE Boot Deep Dive
```
1/ PXE network boot is magic for mass deployments
- No USB drives
- No manual installs
- Just power on and walk away

Here's how we set it up 🧵

[Technical details with commands]
```

## Content Calendar

- **Monday**: Technical how-to (blog post + LinkedIn)
- **Wednesday**: Quick tip or command snippet (X thread)
- **Friday**: Progress update or metric (LinkedIn carousel)

## Metrics to Track

- GitHub stars and forks
- LinkedIn post engagement (likes, comments, shares)
- Twitter/X thread impressions
- Inbound DMs from potential clients

## Community Engagement

- Respond to comments within 24 hours
- Share others' homelab/edtech projects
- Tag relevant communities (#HomeLab, #SysAdmin, #EdTech)
- Credit tools and projects you use

---

**Repo**: [github.com/T-Rylander/legacy-edtech-backbone](https://github.com/T-Rylander/legacy-edtech-backbone)
