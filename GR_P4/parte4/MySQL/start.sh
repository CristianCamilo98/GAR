#!/bin/bash
ansible-galaxy install geerlingguy.mysql
ansible-playbook deploy-mysql.yml
