pipeline {
    agent any

    tools {
        terraform 'Terraform'
        ansible 'Ansible'
    }

    environment {
        TF_VAR_region = 'us-east-1'
        TF_VAR_key_name = 'mykeypairusvir'
        TF_IN_AUTOMATION = 'true'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        ANSIBLE_REMOTE_USER = 'ubuntu'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/tharik-109/mongodb.git'
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform init
                    '''
                }
            }
        }

        stage('Terraform Validate & Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh 'terraform validate'
                    sh 'terraform plan'
                }
            }
        }

        stage('User Input - Choose Action') {
            steps {
                script {
                    def userInput = input message: 'Choose the action to perform:', parameters: [
                        choice(name: 'ACTION', choices: ['Apply', 'Destroy'], description: 'Select whether to apply or destroy.')
                    ]
                    env.ACTION = userInput
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { return env.ACTION == 'Apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Run Ansible Playbook') {
            when {
                expression { return env.ACTION == 'Apply' }
            }
            steps {
                sh '''
                    echo "Waiting for EC2 to initialize..."
                    sleep 60
                    
                    sudo chmod 400 /var/lib/jenkins/mykeypairusvir.pem
                    
                    export ANSIBLE_CONFIG='/var/lib/jenkins/ansible.cfg'
                    export ANSIBLE_HOST_KEY_CHECKING=False
                    
                    ansible-playbook -i inventory.aws_ec2.yml mongodb_setup.yml --private-key="/var/lib/jenkins/mykeypairusvir.pem" -u ubuntu 
                '''
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { return env.ACTION == 'Destroy' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    post {
        always {
            echo ':gear: Pipeline execution completed.'
        }
        success {
            slackSend(
                channel: '#general',
                attachments: [
                    [
                        color: 'good',
                        title: "✅ SUCCESS: ${env.JOB_NAME} (Build #${env.BUILD_NUMBER})",
                        text: """
                            *Job Name:* ${env.JOB_NAME}
                            *Build No:* ${env.BUILD_NUMBER}
                            *Triggered By:* [Started by user admin]
                            
                            This job has completed successfully. 🎉
                            *🔗 <${env.BUILD_URL}|Check logs here>*
                        """,
                        mrkdwn_in: ["text"]
                    ]
                ]
            )

            emailext(
                subject: "✅ SUCCESS: ${env.JOB_NAME} (Build #${env.BUILD_NUMBER})",
                body: """
                    <div style="border: 1px solid #c3e6cb; background-color: #d4edda; padding: 10px; border-radius: 5px;">
                        <h2 style="color: #155724;">✅ Jenkins Job SUCCESS</h2>
                        <p><b>Job Name:</b> ${env.JOB_NAME}</p>
                        <p><b>Build No:</b> ${env.BUILD_NUMBER}</p>
                        <p><b>Triggered By:</b> [Started by user admin]</p>
                        <p>This job has completed successfully. 🎉</p>
                        <p>🔗 <a href='${env.BUILD_URL}' style="color: #155724;">Check logs here</a></p>
                    </div>
                """,
                to: 'mtharik121@gmail.com',
                from: 'mtharik121@gmail.com',
                mimeType: 'text/html'
            )
        }
        failure {
            slackSend(
                channel: '#general',
                attachments: [
                    [
                        color: 'danger',
                        title: "❌ FAILURE: ${env.JOB_NAME} (Build #${env.BUILD_NUMBER})",
                        text: """
                            *Job Name:* ${env.JOB_NAME}
                            *Build No:* ${env.BUILD_NUMBER}
                            *Triggered By:* [Started by user admin]
                            
                            This job has failed. ❗
                            *🔗 <${env.BUILD_URL}|Check logs here>*
                        """,
                        mrkdwn_in: ["text"]
                    ]
                ]
            )

            emailext(
                subject: "❌ FAILURE: ${env.JOB_NAME} (Build #${env.BUILD_NUMBER})",
                body: """
                    <div style="border: 1px solid #f5c6cb; background-color: #f8d7da; padding: 10px; border-radius: 5px;">
                        <h2 style="color: #721c24;">❌ Jenkins Job FAILED</h2>
                        <p><b>Job Name:</b> ${env.JOB_NAME}</p>
                        <p><b>Build No:</b> ${env.BUILD_NUMBER}</p>
                        <p><b>Triggered By:</b> [Started by user admin]</p>
                        <p>This job has failed. ❗</p>
                        <p>🔗 <a href='${env.BUILD_URL}' style="color: #721c24;">Check logs here</a></p>
                    </div>
                """,
                to: 'mtharik121@gmail.com',
                from: 'mtharik121@gmail.com',
                mimeType: 'text/html'
            )
        }
    }
}
