local cjson = require("cjson.safe")

return cjson.decode([==[[
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "185.232.67.220", "type": "ssh", "login": "0101", "status": "success", "valid_user": true}, "name": "pam_successful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "5.196.70.107",   "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "211.250.189.64", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "211.250.189.64", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "211.250.189.64", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "211.250.189.64", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "211.250.189.64", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "159.203.101.80", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "62.11.53.46",    "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "178.128.111.17", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "139.199.31.58",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "139.199.31.58",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "139.199.31.58",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "139.199.31.58",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "139.199.31.58",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "139.199.118.21", "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "106.12.84.112",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "118.24.54.178",  "type": "ssh", "login": "0101", "status": "failed", "valid_user": false}, "name": "pam_unsuccessful_auth"},
  {"data": {"ip": "167.99.136.149", "type": "ssh", "login": "0101", "status": "success", "valid_user": true}, "name": "pam_successful_auth"}
]]==])
