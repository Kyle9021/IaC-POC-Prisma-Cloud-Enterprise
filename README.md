# IaC-POC-Prisma-Cloud-Enterprise

## Assumptions

* You're using the ENTERPRISE EDITION OF PRISMA CLOUD
* You're using ubuntu 20.04
* You're able to reach your Prisma Cloud Enterprise Edition console from your ubuntu 20.04 machine
* You would know how to harden this process if working in a production environment.

* If you do decide to keep the keys in this script, then it's critical you:
  
   * Add it to your `.gitignore` (if using git) file and `chmod 700 iac_script.bash` between steps 3 and 4 below so that others can't read, write, or excute it. 

# Instructions

## Instructions

* Step 1: `git clone https://github.com/Kyle9021/IaC-POC-Prisma-Cloud-Enterprise`
* Step 2: `git clone https://github.com/bridgecrewio/terragoat`
* Step 3: `cd IaC-POC-Prisma-Cloud-Enterprise/`
* Step 4: `nano iac_script.bash` and assign variables according to comment documentation
* Step 5: Install jq if you dont have it `sudo apt update && upgrade -y` then `sudo apt-get install jq` 
* Step 6: Install cowsay `sudo apt install cowsay`
* Step 7: `bash iac_script.bash`


# Links to reference

* [Official JQ Documentation](https://stedolan.github.io/jq/manual/)
* [Grep Documentation](https://www.gnu.org/software/grep/manual/grep.html)
* [Exporting variables for API Calls and why I choose bash](https://apiacademy.co/2019/10/devops-rest-api-execution-through-bash-shell-scripting/)
