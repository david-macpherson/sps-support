## Automated enabling secure turn

The `enable-secure-turn-linux.sh` will run through the following steps

1. Expose the sps-coturn deployment with a domain name
2. Request a certificate
3. Update the sps-coturn deployment to enable secure turn
4. Update the sps-config with the sps-coturn domain
5. Outputting the secure turn server details

Once the script has completed you will need to add the secure turn's address to the list of Custom ICE servers on the SPS application

## Prerequisites

You will need the following information before proceeding

- `<COREWEAVE_NAMESPACE>` the namespace where sps has been installed to
- `<REGION>` The region sps has been installed to
- `<REST_API_ACCESS_KEY>` The rest api access key generated

To obtain these

1. Log in to the [CoreWeave Cloud](https://cloud.coreweave.com/login)
2. Select Applications in the menu on the left
3. Select the deployed Scalable Pixel Streaming application
4. The `<COREWEAVE_NAMESPACE>` can be found when you click the current context drop down in the top right corner
5. The `<REGION>` can be found as the value in the `Installation Values` under common -> region
6. The `<REST_API_ACCESS_KEY>` can be found under the Application Secrets section under restapiaccesskey


## How to

The following instructions are for executing on linux only

### 1. Getting the script

Run the following command to download the scrip
```bash
wget https://raw.githubusercontent.com/david-macpherson/SPS-Support/refs/heads/main/coreweave/secure-turn/scripts/enable-secure-turn-linux.sh
```

### 2. Change permissions

Change the permission on the script to make it executable 

```bash
chmod +x enable-secure-turn-linux.sh
```


### 3. Set global variables

Edit the script and set the `COREWEAVE_NAMESPACE`, `REGION` and `REST_API_ACCESS_KEY` global variables

```bash
COREWEAVE_NAMESPACE=""
REGION=""
REST_API_ACCESS_KEY=""
```

### 4. Run the script

Once the global variables have been set, execute the following command

```bash
./enable-secure-turn-linux.sh
```

Once the script has completed the url, username and credential for the turn server will be displayed

### 5. Add secure turn to an SPS Application

In order for the application to use secure turn the secure turn will need to be added to the custom ice servers list

1. When creating/updating an application the secure turn address needs to be added to the list of custom ice servers
2. Log into the SPS Dashboard
3. Create or Update an application
4. Select the `Custom Ice Servers` tab on the left hand side
5. Press the `+` button to add a new entry
6. In the `URLs` input enter the following value substituting `<REGION>` and `<COREWEAVE_NAMESPACE>`  
`turns:turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud:443?transport=tcp`
7. In the `Username` field enter `sps-coturn-user`
8. In the `Credential` field enter the output from the following command
```bash
kubectl get configmap sps-coturn -o "jsonpath={.data['credential']}"
```


### Further notes on Secure Turn
If secure TURN is only required then the following is required
- Only have the `turns:turn-<REGION>.<COREWEAVE_NAMESPACE>.coreweave.cloud:443?transport=tcp` entry in the `Custom Ice Servers`
- When creating an version disable the turn server
  - Under the `Advanced` tab
  - Disable the `Enable TURN Server`

Once the version has been made active the application will only stream using secure TURN
