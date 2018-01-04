#!/bin/sh

SID=junkyard

function getBooleanHss {
	echo "getBooleanHss [1/0y/n/Y/N]"
	echo $1
	read junk
	if [ $junk = "y" ]
	then
		return 0
	else
		return 1
	fi
}


function getBooleanHssOrDie {
	while :
	do
		echo "getBooleanHss [1/0y/n/Y/N]"
		echo $1
		read junk
		if [ $junk = "y" ]
		then
			break	
		fi
	done

}

function install {
	aws cloudformation create-stack --region $1  --stack-name ${SID}-codecommit \
		--template-body file://codecommit-template.json
	
	getBooleanHssOrDie "Say y when the ${SID}-codecommit stack is complete and the release is pushed..."

	aws cloudformation create-stack --region $1  --stack-name ${SID}-roles \
		--template-body file://service-roles-template.json --capabilities CAPABILITY_IAM

	aws cloudformation create-stack --region $1  --stack-name ${SID}-vpc \
		--template-body file://vpc-2az-template.json

	while :
	do
		getBooleanHss "Say y when the ${SID}-vpc stack is complete..."
		if [ $? -eq 0 ]
		then
			break
		fi
	done

	aws cloudformation create-stack --region $1  --stack-name ${SID}-codebuild \
		--template-body file://codebuild-template.json

	aws cloudformation create-stack --region $1  --stack-name ${SID}-codedeploy \
		--template-body file://codedeploy-template.json 


	while :
	do
		getBooleanHss "Say y when the ${SID}-codedeploy stack is complete..."
		if [ $? -eq 0 ]
		then
			break
		fi
	done

	aws cloudformation create-stack --region $1  --stack-name ${SID}-pipeline \
		--template-body file://pipeline-short-template.json \
		--parameters ParameterKey=Email,ParameterValue=launchpadmcjeff@gmail.com

}


function uninstall {
	aws cloudformation delete-stack --region $1 --stack-name ${SID}-blue-green
	aws cloudformation delete-stack --region $1 --stack-name ${SID}-pipeline
	while :
	do
		getBooleanHss "Say y when the ${SID}-pipeline stack is deleted..."
		if [ $? -eq 0 ]
		then
			break
		fi
	done
	aws cloudformation delete-stack --region $1 --stack-name ${SID}-codedeploy

	aws cloudformation delete-stack --region $1 --stack-name ${SID}-codebuild

	aws s3 rm s3://${SID}-vpc-codepipeline-$1 --recursive

	aws cloudformation delete-stack --region $1 --stack-name ${SID}-vpc


	aws cloudformation delete-stack --region $1 --stack-name ${SID}-roles

}



if [ "$1" = "install" ]
then
	echo "install needs repo and key"
	install $2
fi

if [ "$1" = "uninstall" ]
then
	echo "uninstalling..."
	uninstall $2
fi

echo "done $1"
