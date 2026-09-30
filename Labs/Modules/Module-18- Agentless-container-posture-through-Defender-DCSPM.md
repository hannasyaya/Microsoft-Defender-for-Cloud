# **Module 18 - Agentless container posture through Defender CSPM**

<p align="left"><img src="../Images/asc-labs-intermediate.gif?raw=true"></p>

#### 🎓 Level: 200 (Intermediate)
#### ⌛ Estimated time to complete this lab: 60 minutes
#### 💁 Authors: Shani Freund Menscher, Future Kortor  


# **Objectives**
In this exercise, you will learn how to enable agentless container security in Defender for Cloud Security Posture Management (CSPM) and identify security risks across your container registries and Kubernetes, all without the need of an agent. Note that you need either owner permissions or user access admin and security admin on the subscription to successfully complete this lab.

See the [official Agentless Container Posture documentation](https://learn.microsoft.com/en-us/azure/defender-for-cloud/concept-agentless-containers).

Learn more about different use cases for container security in Microsoft Defender for cloud: [Container Security in Microsoft Defender for Cloud](https://techcommunity.microsoft.com/t5/microsoft-defender-for-cloud/container-security-with-microsoft-defender-for-cloud/ba-p/3819956)

Learn how to enable how to enable agentless container security posture: [One click to cover containers and Kubernetes in Defender CSPM (agentless)](https://techcommunity.microsoft.com/t5/microsoft-defender-for-cloud/one-click-to-cover-containers-amp-kubernetes-in-defender-cspm/ba-p/3822435)


## **Exercise 1: Prepare your environment.**

Before we set up the resources to be used for this lab, we first need to turn on agentless discovery of Kubernetes and agentless container image scanning in Defender CSPM. Note that Defender for Containers also provides agentless container image scanning but does not include attack paths. You can enable agentless container posture in the Defender for Cloud portal by going to Environment Settings. Once you select your Azure Subscription, make sure Defender CSPM is turned on, click monitoring coverage and turn on “Agentless discovery for Kubernetes” and “Container registries vulnerability assessments”.

![](../Images/enablecontainersdcspm.png?raw=true)

Now that we’ve turned on the features needed from Defender CSPM, we can prepare our resources. 

**1. Attach your Azure Container Registry to an Azure Kubernetes Service Cluster**
 
 In module one, you deployed an ARM template that included an Azure Kubernetes Service cluster and an Azure Container Registry. Now you need to point your Azure Kubernetes Service instance to pull images from the Azure Container Registry.  Only change the part in <>. 

Use the following ***cloud shell*** command line to point your AKS instance to pull images from the selected ACR [read more](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration?tabs=azure-cli#configure-acr-integration-for-existing-aks-clusters):

```
az aks update -n <myAKSCluster> -g <your-ResourceGroup> --attach-acr <your-acr-name>
```

Ex: 
```
az aks update -n asclab-aks -g labgroup --attach-acr asclabacr123
```


Wait for the role propagation to finish running. AAD role propagation should show 100% when this step is successfully completed as shown in the image below.

![](../Images/dcspmrolepropagation.png?raw=true)


**2. Pull a base image and tag with the following label to push to your ACR. Remember to replace the text in <>.**

Run in cloud shell: 

```
docker pull alpine
docker tag alpine <MYACR>.azurecr.io/mdc-mock-0001
docker push <MYACR>.azurecr.io/mdc-mock-0001
```

> [!NOTE]
> Azure Cloud Shell doesn't include a Docker engine, so the `docker` commands above fail there. Import the image directly into your registry instead; no Docker needed:
> ```
> az acr import --name <MYACR> --source docker.io/library/alpine:latest --image mdc-mock-0001:latest
> ```
> Your image URI for step 4 is then `<MYACR>.azurecr.io/mdc-mock-0001:latest`. If the import fails with a Docker Hub rate-limit error (`toomanyrequests`), wait a few minutes and retry.


**3.	Allow work on the cluster:**

```
az aks get-credentials  --subscription <your-subscriptionid> --resource-group <your-rg-name> --name <your-cluster-name>
```

**4.	First, Install the ngnix ingress Controller. Then, deploy a mock vulnerable image and expose the vulnerable container to the internet.**

```
helm install ingress-controller oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.0.1

helm install dcspmcharts  oci://mcr.microsoft.com/mdc/stable/dcspmcharts --version 1.0.0 --namespace mdc-dcspm-demo --create-namespace --set image=<your-image-uri> --set distribution=AZURE
```

**5.	Verify success of the deployment:**

Verify success by navigating to your AKS cluster and check for the following:

- Look for an entry with mdc-dcspm-demo as the namespace
![](../Images/verifynamespacedeployment.png?raw=true)

- In Workloads-> Deployments tab verify “pod” created 3/3 and “dcspmcharts-ingress-nginx-controller” 1/1.
![](../Images/verifycontainersdeployment.png?raw=true)

- In services and ingresses look for-> services “service”, “dcspmcharts-ingress-nginx-controller” and “dcspmcharts-ingress-nginx-controller-admission”. In the ingress tab you should verify one “ingress” is created with an ip address and nginx class.

![](../Images/verifyservicesdeployment.png?raw=true)
![](../Images/verifyingressdeployment.png?raw=true)
 

**6.	Waiting period of six hours**

The system’s architecture is based on a snapshotting mechanism with an interval of every 6 hours, which is typically the time to observe inventory. For insights and attack paths it can take up to 24 hours. 
From there, we can investigate the deployment via the Cloud Security Explorer and Attack paths.



## **Exercise 2: Investigate internet exposed Kubernetes pods through the Cloud Security Explorer**

From the Defender for Cloud overview page, open the Cloud Security Explorer (Preview) page. 

![](../Images/opencloudsecurityexplorer.png?raw=true)
 
You’ll notice some out of the box templates for Kubernetes such as the two examples below. Click “open query, then "search" to view the results. Both templates should yield results from our environment setup:

**1.	Azure Kubernetes pods running images with high severity** vulnerabilities.

![](../Images/queryrunningpods.png?raw=true)

![](../Images/queryrunningpodsresults.png?raw=true)
 
**2.	Kubernetes namespaces contain vulnerable pods.**

 ![](../Images/vulnerablenamespace.png?raw=true)

 ![](../Images/vulnerablenamespaceresults.png?raw=true)

 
You can also create your own queries. For this example, we’ll search for pods running container images that are vulnerable to remote code execution.

**1.	Start by searching for pods.**

![](../Images/querypods1.png?raw=true)

**2.	Click on the plus sign and select “application” then “Is running” then select “containers”:**

![](../Images/querypods2.png?raw=true)
 
**3.	Click on the plus sign next to “Containers and select “Application” and “Is running” again to add the container images:**

![](../Images/querypods3.png?raw=true)
 
**4.	Click on the plus sign next to Container images and select “Security” then “Vulnerable to remote code execution.”**

![](../Images/querypods4.png?raw=true)
 
**5.	The query is complete! Click search to view the results. You should see the three pods we onboarded.**
![](../Images/querypods5.png?raw=true)



## **Exercise 3: Investigate attack paths**
In exercise one, we exposed our Kubernetes Service to the internet and ran a high severity image on the cluster. This triggered the attack path “Internet exposed Kubernetes pod is running a container with high severity vulnerabilities”. To investigate the attack path, navigate to the Defender for Cloud portal and click:

•	Recommendations

•	Attack paths

•	Select the attack path mentioned above

![](../Images/containersattackpath.png?raw=true)
 
In the attach path, you will notice it detected the namespace “mdc-dcspm-demo”, container “hello-contoso” and the image “mdc-mock-001”, all of which we deployed in Exercise 1. With the attack path, you can see all the resource types involved in this path as well as how they are related. For example, the attack path shows you that the “mdc-dcspm-demo” is contained inside the asclab cluster and routes traffic to the service we deployed for internet exposure.
To see how to remediate the attack path, scroll down to the “Remediation Steps” and navigate to the “Recommendations” tab. 

![](../Images/attackpathVArecommendation.png?raw=true)


