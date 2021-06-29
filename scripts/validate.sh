#!/bin/bash

if [ ! -f .bin/opa ]; then 
    mkdir -p .bin
    curl -L -o .bin/opa https://openpolicyagent.org/downloads/v0.29.4/opa_linux_amd64
    chmod 755 .bin/opa
fi

terraform plan -out tfplan.binary
terraform show -json tfplan.binary > tfplan.json
.bin/opa eval --format pretty  --data policies/terraform.rego --input tfplan.json "data" 