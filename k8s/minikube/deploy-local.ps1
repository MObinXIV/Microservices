$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$services = @('customer', 'fraud', 'notification')
$helperImage = 'gcr.io/go-containerregistry/crane:debug'
$helperPod = 'registry-pusher'
$createdHelper = $false
$archives = @()

Push-Location $repoRoot
try {
    $context = kubectl config current-context
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read the current kubectl context.'
    }
    if ($context.Trim() -ne 'minikube') {
        throw "Expected kubectl context 'minikube', found '$($context.Trim())'."
    }

    minikube status
    if ($LASTEXITCODE -ne 0) {
        throw 'Minikube is not running. Start it with: minikube start'
    }

    minikube addons enable registry
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to enable the Minikube registry addon.'
    }

    mvn -pl customer,fraud,notification -am -P build-docker-image -DskipTests clean package
    if ($LASTEXITCODE -ne 0) {
        throw 'The Maven image build failed.'
    }

    docker image inspect $helperImage --format '{{.Id}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        docker pull $helperImage
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to pull the image-transfer helper $helperImage."
        }
    }

    minikube image load $helperImage
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to load $helperImage into Minikube."
    }

    $existingHelper = kubectl get pod $helperPod --ignore-not-found -o name
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to check for the temporary image-transfer pod.'
    }
    if (-not $existingHelper) {
        kubectl run $helperPod --image=$helperImage --image-pull-policy=IfNotPresent --restart=Never --command -- /busybox/sleep 3600
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to create the temporary image-transfer pod.'
        }
        $createdHelper = $true
    }

    kubectl wait --for=condition=Ready "pod/$helperPod" --timeout=120s
    if ($LASTEXITCODE -ne 0) {
        throw 'The temporary image-transfer pod did not become ready.'
    }

    foreach ($service in $services) {
        $archive = ".\.minikube-image-$service-$([guid]::NewGuid().ToString('N')).tar"
        $archives += $archive

        docker save --output $archive "mobinxiv/${service}:latest"
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to archive the $service image."
        }

        kubectl cp $archive "${helperPod}:/tmp/${service}.tar"
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to copy the $service image to Minikube."
        }

        kubectl exec $helperPod -- /ko-app/crane push --insecure "/tmp/${service}.tar" "registry.kube-system.svc.cluster.local:80/mobin/${service}:latest"
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to push the $service image to the Minikube registry."
        }

        kubectl exec $helperPod -- /busybox/rm -f "/tmp/${service}.tar"
    }

    kubectl apply -R -f .\k8s\minikube\services
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to apply the Minikube service manifests.'
    }

    foreach ($service in $services) {
        kubectl rollout status "deployment/$service" --timeout=180s
        if ($LASTEXITCODE -ne 0) {
            throw "The $service deployment did not roll out successfully."
        }
    }
}
finally {
    foreach ($archive in $archives) {
        if (Test-Path $archive) {
            Remove-Item -LiteralPath $archive -Force
        }
    }
    if ($createdHelper) {
        kubectl delete pod $helperPod --wait=false 2>$null | Out-Null
    }
    Pop-Location
}
