import groovy.json.JsonOutput

def scripts(hostPath, containerPath) {
  // shelling out to ls is a hack because we do not have https://jenkins.io/doc/pipeline/steps/pipeline-utility-steps/#findfiles-find-files-in-the-workspace
  sh(script: "ls ${hostPath}", returnStdout: true)
  .trim().split("(\\s|\\r|\\n)+").collect { file ->
    "${containerPath}/${file.split('/').last()}"
  }.join(" ")
}

def slackSendNotification(color = '', messageType = '', nonGenericMessage = false) {
  if (color != '' && messageType != '') {
    // slackSend
    withCredentials([[$class: 'StringBinding', credentialsId: 'SLACK_INTEGRATION_TOKEN', variable: 'SLACK_INTEGRATION_TOKEN']]) {
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
    dockerImage = ''
    SLACK_CHANNEL = '#dev-infra-updates'
  }
  stages {
    stage('ShellCheck') {
      steps {
        script {
          sh "docker run --rm -v " +
          "${env.WORKSPACE}/configurator/sysdig-chart:/sysdig-chart koalaman/shellcheck --exclude=SC2164,SC1090 -- " +
          scripts("${env.WORKSPACE}/configurator/sysdig-chart/*.sh", "/sysdig-chart")
        }
      }
    }
    stage('Build image') {
      when {
        branch 'Templating_k8s_configurations'
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
            dockerImage = docker.build("${env.ARTIFACTORY_URL}/configurator:${env.BUILD_NUMBER}", './configurator/')
          }
        }
      }
    }
    stage('Push image') {
      when {
        branch 'Templating_k8s_configurations'
      }
      steps {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
            docker.withRegistry("https://${env.ARTIFACTORY_URL}", registryCredential) {
              dockerImage.push()
              dockerImage.push('latest')
            }
          }
        }
      }
      post {
        success {
          script {
            slackSendNotification("${env.SLACK_COLOR_GOOD}", "Pushed docker image: ${env.ARTIFACTORY_URL}/configurator:${env.BUILD_NUMBER}")
          }
        }
      }
    }
    stage('Cleanup') {
      when {
        branch 'Templating_k8s_configurations'
      }
      steps {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          sh "docker rmi ${env.ARTIFACTORY_URL}/configurator:${env.BUILD_NUMBER}"
        }
      }
    }
  }

  post {
    failure {
      script {
        slackSendNotification("${env.SLACK_COLOR_DANGER}", "FAILED")
      } }
    success {
      script {
        slackSendNotification("${env.SLACK_COLOR_GOOD}", "SUCCESS")
      }
    }
  }
}
