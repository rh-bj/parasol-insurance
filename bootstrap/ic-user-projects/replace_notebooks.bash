#!/bin/bash

user_count=$(oc get namespaces | grep showroom | wc -l)
WORKBENCH_NAME="my-workbench"
WORKBENCH_IMAGE="ic-workbench:1.2"
PIPELINE_ENGINE="Argo"
BRANCH_NAME="kor-rhoai-2.13"

for i in $(seq 1 $user_count);
do

# Construct dynamic variables
USER_NAME="user$i"
USER_PROJECT="user$i"

cat << EOF | oc apply -f-
apiVersion: batch/v1
kind: Job
metadata:
  name: replace-cloned-repo
  namespace: $USER_PROJECT
spec:
  backoffLimit: 4
  template:
    spec:
      serviceAccount: demo-setup
      serviceAccountName: demo-setup
      initContainers:
      - name: wait-for-workbench
        image: image-registry.openshift-image-registry.svc:5000/openshift/tools:latest
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args:
        - -ec
        - |-
          echo -n "Waiting for workbench pod in $USER_PROJECT namespace"
          while [ -z "\$(oc get pods -n $USER_PROJECT -l app=$WORKBENCH_NAME -o custom-columns=STATUS:.status.phase --no-headers | grep Running 2>/dev/null)" ]; do
              echo -n '.'
              sleep 1
          done
          echo "Workbench pod is running in $USER_PROJECT namespace"
      containers:
      - name: git-clone
        image: image-registry.openshift-image-registry.svc:5000/openshift/tools:latest
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args:
        - -ec
        - |-
          pod_name=\$(oc get pods --selector=app=$WORKBENCH_NAME -o jsonpath='{.items[0].metadata.name}') && oc exec \$pod_name -- bash -c "rm -Rf parasol-insurance && git clone https://github.com/rh-bj/parasol-insurance && cd parasol-insurance && git checkout $BRANCH_NAME && rm -Rf bootstrap content default-site.yml LICENSE README.md"
      restartPolicy: Never
EOF
sleep 20
done
