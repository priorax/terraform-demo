import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.script
import jetbrains.buildServer.configs.kotlin.v2019_2.triggers.finishBuildTrigger
import jetbrains.buildServer.configs.kotlin.v2019_2.triggers.vcs

/*
The settings script is an entry point for defining a TeamCity
project hierarchy. The script should contain a single call to the
project() function with a Project instance or an init function as
an argument.

VcsRoots, BuildTypes, Templates, and subprojects can be
registered inside the project using the vcsRoot(), buildType(),
template(), and subProject() methods respectively.

To debug settings scripts in command-line, run the

    mvnDebug org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate

command and attach your debugger to the port 8000.

To debug in IntelliJ Idea, open the 'Maven Projects' tool window (View
-> Tool Windows -> Maven Projects), find the generate task node
(Plugins -> teamcity-configs -> teamcity-configs:generate), the
'Debug' option is available in the context menu for the task.
*/

version = "2021.1"

project {

    buildType(Plan)
    buildType(Validate)
    buildType(Destroy)
    buildType(Deploy)
    buildTypesOrder = arrayListOf(Validate, Plan)
}

object Deploy : BuildType({
    name = "Deploy"

    buildNumberPattern = "${Plan.depParamRefs.buildNumber}"

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Terraform Install"
            scriptContent = """
                #!/bin/bash
                if [ ! -f .tfenv/bin/terraform ]; then
                	git clone https://github.com/tfutils/tfenv.git .tfenv
                fi
                .tfenv/bin/tfenv install 1.0.1
                .tfenv/bin/tfenv use 1.0.1
                .tfenv/bin/terraform init
            """.trimIndent()
        }
        script {
            scriptContent = """
                #!/bin/bash -x
                .tfenv/bin/terraform apply -no-color -auto-approve tfplan.binary
            """.trimIndent()
        }
    }

    triggers {
        finishBuildTrigger {
            buildType = "${Plan.id}"
            successfulOnly = true
        }
    }

    dependencies {
        dependency(Plan) {
            snapshot {
                onDependencyFailure = FailureAction.CANCEL
            }

            artifacts {
                artifactRules = "*=>."
            }
        }
    }
})

object Destroy : BuildType({
    name = "Destroy"

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Install terraform"
            scriptContent = """
                #!/bin/bash
                if [ ! -f .tfenv/bin/terraform ]; then
                	git clone https://github.com/tfutils/tfenv.git .tfenv
                fi
                .tfenv/bin/tfenv install 1.0.1
                .tfenv/bin/tfenv use 1.0.1
                .tfenv/bin/terraform init
            """.trimIndent()
        }
        script {
            name = "Destroy"
            scriptContent = ".tfenv/bin/terraform destroy -auto-approve"
        }
    }
})

object Plan : BuildType({
    name = "Plan"

    artifactRules = "tfplan.*"
    buildNumberPattern = "${Validate.depParamRefs["env.BUILD_NUMBER"]}"
    publishArtifacts = PublishMode.SUCCESSFUL

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Install tfenv"
            scriptContent = """
                #!/bin/bash
                if [ ! -f .tfenv/bin/terraform ]; then
                git clone https://github.com/tfutils/tfenv.git .tfenv
                fi
            """.trimIndent()
        }
        script {
            name = "Install terraform"
            scriptContent = """
                #!/bin/bash
                ls -la
                echo ${'$'}PATH
                .tfenv/bin/tfenv install 1.0.1
                .tfenv/bin/tfenv use 1.0.1
            """.trimIndent()
        }
        script {
            name = "Terraform Plan"
            scriptContent = """
                .tfenv/bin/terraform init -reconfigure
                .tfenv/bin/terraform plan -out tfplan.binary
                .tfenv/bin/terraform show -json tfplan.binary > tfplan.json
            """.trimIndent()
        }
    }

    triggers {
        finishBuildTrigger {
            buildType = "${Validate.id}"
            successfulOnly = true
        }
    }

    dependencies {
        snapshot(Validate) {
        }
    }
})

object Validate : BuildType({
    name = "Validate"

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Install terraform"
            scriptContent = """
                #!/bin/bash
                git clone https://github.com/tfutils/tfenv.git .tfenv
                .tfenv/bin/tfenv install 1.0.1
                .tfenv/bin/tfenv use 1.0.1
                .tfenv/bin/terraform init -reconfigure
            """.trimIndent()
        }
        script {
            name = "Terraform validate"
            scriptContent = ".tfenv/bin/terraform validate"
        }
        script {
            name = "OPA"
            scriptContent = """
                chmod +x ./scripts/validate.sh
                ./scripts/validate.sh
            """.trimIndent()
        }
        script {
            name = "Test"
            scriptContent = """
                #!/bin/bash
                if [ ! -f .bin/gimme ]; then
                  mkdir -p .bin
                  curl -sL -o .bin/gimme https://raw.githubusercontent.com/travis-ci/gimme/master/gimme
                  chmod +x .bin/gimme
                fi
                eval ${'$'}(.bin/gimme 1.15)
                export PATH=${'$'}(pwd)/.tfenv/bin:${'$'}PATH
                cd test
                go test -v .
            """.trimIndent()
        }
    }

    triggers {
        vcs {
            branchFilter = ""
        }
    }
})
