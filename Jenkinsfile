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
                    dir('') {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            terraform init
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate & Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    dir('') {
                        sh 'terraform validate'
                        sh 'terraform plan'
                    }
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
                    dir('') {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            when {
                expression { return env.ACTION == 'Apply' }
            }
            steps {
                script {
                    sh '''
                        echo "Waiting for EC2 to initialize..."
                        sleep 60

                        # Ensure correct permissions for the SSH key
                        sudo chmod 400 /var/lib/jenkins/mykeypairusvir.pem

                        # Set Ansible environment variables
                        export ANSIBLE_CONFIG='/var/lib/jenkins/ansible.cfg'
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        # Run Ansible playbook with dynamic inventory
                        ansible-playbook -i inventory.aws_ec2.yml mongodb_setup.yml --private-key="/var/lib/jenkins/mykeypairusvir.pem" -u ubuntu 
                    '''
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { return env.ACTION == 'Destroy' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    dir('') {
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
    }

    post {
        always {
            echo ':gear: Pipeline execution completed.'
        }
        success {
            slackSend channel: '#general', message: "✅ SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER} completed!", color: 'good'
            emailext(
                subject: "Jenkins Pipeline SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "<p>Pipeline <b>${env.JOB_NAME}</b> completed successfully.</p><p><a href='${env.BUILD_URL}'>View Build</a></p>",
                to: 'mtharik121@gmail.com',
                mimeType: 'text/html'
            )
        }
        failure {
            slackSend channel: '#general', message: "❌ FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER} failed!", color: 'danger'
            emailext(
                subject: "Jenkins Pipeline FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "<p>Pipeline <b>${env.JOB_NAME}</b> failed.</p><p><a href='${env.BUILD_URL}'>View Build</a></p>",
                to: 'mtharik121@gmail.com',
                mimeType: 'text/html'
            )
        }
    }
}
