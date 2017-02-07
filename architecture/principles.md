## Principles
- Dependencies may only go down or sideways, never up (e.g. from Layer 2 to Layer 3)
- Componentization / Design for upgradability: Strive for self-contained components so that they can be upgraded independently of each other. For example:
  - RHEL-OSP with default SDN can be replaced whith RHEL-OSP with 3rd party SDN without affecting any other component
  - A subset of the demo with smaller footprint can be extracted easily, e.g. just OpenStack (running on bare metal) + CloudForms + OpenShift
- Immutable Infrastructure: No manual configuration, EVERYTHING needs to be scripted.
  - "Scripts" in this context means code that is checked into a repository,
  be it puppet classes, ansible playbooks, shell scripts or similar
  - Events to create scripts for:
    - Creation
    - Deletion
    - Startup
    - Shutdown
    - Data Export (e.g. satellite subscription data, openstack base images, ....)
    - Data Import
    - Reset to known state (demo reset)
    - Validation (to ensure the demo will likely work at a known date in the future)
  - This will reduce the need for backup / restore: Instead of backup up/restoring a known good configuration, we can recreate it from scratch
- Test (Driven/Augmented) Development: For all use cases, tests should be added
to the repository so a correct behavior can be validated. This includes testing the scripts to set up / tear down components as well as testing demo use cases.
  - To be discussed:
    - Level/Rigor of testing
    - Test Automation / Continuous Build
