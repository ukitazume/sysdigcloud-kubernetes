import groovy.json.JsonOutput

def nextReleaseTag() {
  sh(returnStdout: true, script: "cat configurator/next_version").trim()
}

def dockerImage() {
  "${env.ARTIFACTORY_URL}/configurator:${nextReleaseTag()}-rc${env.BUILD_NUMBER}"
}

def dockerNonRCImage() {
  "${env.ARTIFACTORY_URL}/configurator:${nextReleaseTag()}"
}

def uberImage() {
  "${env.ARTIFACTORY_URL}/configurator:${nextReleaseTag()}-uber-rc${env.BUILD_NUMBER}"
}

def uberNonRCImage() {
  "${env.ARTIFACTORY_URL}/configurator:${nextReleaseTag()}-uber"
}

def quayImage() {
  "quay.io/sysdig/configurator:${env.TAG_NAME}"
}

def quayUberImage() {
  "quay.io/sysdig/configurator:${env.TAG_NAME}-uber"
}

def slackSendNotification(color = '', messageType = '', nonGenericMessage = false) {
  if (color != '' && messageType != '') {
    // slackSend
    withCredentials([
      [$class: 'StringBinding', credentialsId: 'SLACK_INTEGRATION_TOKEN', variable: 'SLACK_INTEGRATION_TOKEN'],
      string(credentialsId: 'devops-slack-channel', variable: 'SLACK_CHANNEL')
    ]) {
      if (nonGenericMessage) {
        message = messageType
      } else {
        message = "*${messageType}*: Job ${env.JOB_NAME} build ${env.BUILD_NUMBER}"
      }
      message += " (<${env.BUILD_URL}|Open>)"
      def payload = JsonOutput.toJson([
        "channel": "${env.SLACK_CHANNEL}",
        "attachments": [[
          "fallback": "${message}",
          "color": "${color}",
          "fields": [[
            "short": false,
            "value": "${message}",
          ]],
          "mrkdwn_in": [
            "pretext",
            "text",
            "fields",
          ]
        ]]
      ])
      apiUrl = "https://${env.SLACK_TEAM_DOMAIN}.slack.com/services/hooks/jenkins-ci?token=${env.SLACK_INTEGRATION_TOKEN}"
      response = sh(returnStdout: true,
        script: "curl -s -H \"Content-type: application/json\" -X POST -d '${payload}' ${apiUrl}"
      ).trim()
    }
  }
}

pipeline {
  agent {
    node { label "${WORKER}" }
  }
  environment {
    registryCredential = 'jenkins-artifactory'
  }
  stages {
    stage('ShellCheck') {
      when {
        not { equals expected: nextReleaseTag(), actual: env.TAG_NAME }
      }
      steps {
        script {
          sh "cd configurator && make shellcheck"
        }
      }
    }
    stage('Test') {
      when {
        not { equals expected: nextReleaseTag(), actual: env.TAG_NAME }
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
              sh(
                "cd configurator && " +
                "IMAGE_NAME=${dockerImage()} make test"
              )
          }
        }
      }
      post {
        cleanup {
          withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${env.ARTIFACTORY_URL}/configurator:${env.BUILD_NUMBER} || /bin/true")
            }
          }
        }
      }
    }
    stage('Test uber_tar') {
      when {
        not { equals expected: nextReleaseTag(), actual: env.TAG_NAME }
      }
      steps{
        script {
          docker.withRegistry("https://quay.io", "QUAY") {
            sh(
              "cd configurator && " +
              "IMAGE_NAME=${dockerImage()} make test_uber_tar"
            )
          }
        }
      }
      post {
        cleanup {
          script {
            sh "cd configurator && make clean"
            sh "docker rmi -f \$(docker images -qa) || /bin/true"
          }
        }
      }
    }
    stage('Push RC git tag') {
      when {
        // branch 'Templating_k8s_configurations'
        branch 'tagging_scheme'
      }
      steps{
        withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-github-ssh-key', keyFileVariable: 'sshkey')]) {
          script {
            gitTag = "${nextReleaseTag()}-rc${env.BUILD_NUMBER}"
            sh(
              "git tag -m ${gitTag} ${gitTag} && " +
              "GIT_SSH_COMMAND=\"ssh -i ${sshkey}\" git push origin --tags"
            )
          }
        }
      }
    }
    stage('Push internal image') {
      when {
        // branch 'Templating_k8s_configurations'
        branch 'tagging_scheme'
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
            docker.withRegistry("https://${env.ARTIFACTORY_URL}", registryCredential) {
              sh(
                "cd configurator && IMAGE_NAME=${dockerImage()} make push && " +
                "docker tag ${dockerImage()} ${dockerNonRCImage()} && " +
                "docker push ${dockerNonRCImage()}"
              )
            }
          }
        }
      }
      post {
        success {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              slackSendNotification("${env.SLACK_COLOR_GOOD}", "Pushed docker image: ${dockerImage()}")
            }
          }
        }
        cleanup {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${dockerImage()} || /bin/true")
            }
          }
        }
      }
    }
    stage('Push internal uber_image') {
      when {
        // branch 'Templating_k8s_configurations'
        branch 'tagging_scheme'
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
            docker.withRegistry("https://${env.ARTIFACTORY_URL}", registryCredential) {
              sh(
                "cd configurator && " +
                "IMAGE_NAME=${dockerImage()} UBER_IMAGE_NAME=${uberImage()} make push_uber_tar && " +
                "docker tag ${uberImage()} ${uberNonRCImage()} && " +
                "docker push ${uberNonRCImage()}"
              )
            }
          }
        }
      }
      post {
        success {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              slackSendNotification("${env.SLACK_COLOR_GOOD}", "Pushed docker image: ${uberImage()}")
            }
          }
        }
        cleanup {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${dockerImage()} || /bin/true")
              sh("docker rmi ${uberImage()} || /bin/true")
            }
          }
        }
      }
    }
    stage('Promote image to quay') {
      when {
        equals expected: nextReleaseTag(), actual: env.TAG_NAME
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
              docker.withRegistry("https://${env.ARTIFACTORY_URL}", registryCredential) {
                sh("docker pull ${dockerNonRCImage()}")
              }
              docker.withRegistry("https://quay.io", "QUAY") {
                sh(
                  "docker tag ${dockerNonRCImage()} ${quayImage()} && " +
                  "docker push ${quayImage()}"
                )
              }
          }
        }
      }
      post {
        success {
          script {
            slackSendNotification("${env.SLACK_COLOR_GOOD}", "Pushed docker image: quay.io/sysdig/configurator:${env.TAG_NAME}")
          }
        }
        cleanup {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${dockerNonRCImage()} || /bin/true")
            }
          }
        }
      }
    }
    stage('Promote uber_image to quay') {
      when {
        equals expected: nextReleaseTag(), actual: env.TAG_NAME
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
              docker.withRegistry("https://${env.ARTIFACTORY_URL}", registryCredential) {
                sh("docker pull ${uberNonRCImage()}")
              }
              docker.withRegistry("https://quay.io", "QUAY") {
                sh (
                "docker tag ${uberNonRCImage()} ${quayUberImage()} && " +
                "docker push ${quayUberImage()}"
                )
              }
          }
        }
      }
      post {
        success {
          script {
            slackSendNotification("${env.SLACK_COLOR_GOOD}", "Pushed docker image: ${quayUberImage()}")
          }
        }
        cleanup {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${uberNonRCImage()} || /bin/true")
            }
          }
        }
      }
    }
  }
  post {
    failure {
      script {
        slackSendNotification("${env.SLACK_COLOR_DANGER}", "FAILED")
      }
    }
    success {
      script {
        slackSendNotification("${env.SLACK_COLOR_GOOD}", "SUCCESS")
      }
    }
  }
}
