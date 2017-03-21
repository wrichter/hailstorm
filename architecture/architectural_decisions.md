# Architecture Decisions

## AD01 - Transport and Update approach
How is the demo to be transported to partners and other recipients; how is the demo environment updated to the latest product versions.
  * Alternatives:
    1. Maintain & transport a set of virtual machine images, transport these virtual machine images. Create/update the demo in other places by installing & instantiating VM images.
    2. Maintain & transport automation scripts to create & configure the demo. Create/update the demo in other places by running the automation scripts.
  * Choice: Approach 2 - Automation scripts
  * Assessment:
    * Pros Approach 1:
      * Easy to install
      * Quick to install
    * Cons Approach 1:
      * Large binaries need to be transported
      * Approach allows for undocumented tweaking of environment
      * Reset to a "freshly installed" condition means restarting from zero
      * Unclear how to adjust the resulting setup to changing IP adresses, domain names, etc.
    * Pros Approach 2:
      * Each resulting environment yields a "freshly installed" environment
      * Adjustments regarding the environment, features, etc... can be made as part of the rollout
      * Automation scripts easily transportable
      * Avoids updates on installed components
    * Cons Approach 2:
      * Approximately 4x the effort to automate the setup (vs. just manually installing it) - 2x to automate it with Ansible and 2x to make the script idempotent
      * Setup process / execution is more difficult / error prone
  * Impact:
    * Training effort required to enable others to set up and install the environment


## AD02 - Layer 1 Technology Choice
What virtualization technology will be used to realize layer1.
  * Alternatives:
    1. Libvirt (RHEL)
    2. oVirt (Red Hat Virtualization)
    3. OpenStack
  * Choice: Approach 1 - Libvirt (RHEL)
  * Assessment:
    * Pros Approach 1
    * Cons Approach 1
    * Pros Approach 2
    * Cons Approach 2
    * Pros Approach 3
    * Cons Approach 3
  * Impact
