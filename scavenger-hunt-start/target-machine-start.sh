#!/bin/bash

# got root?
if [ "$EUID" -ne 0 ]
  then printf '\n%s\n\n' \
  "Please run as root." \
  "HINT: Use sudo!" 
  exit
fi

#got docker?
printf '\n%s\n'  "Making sure docker is running..." 
if pgrep docker &> /dev/null
then
  printf '\n%s\n\n' "Docker is running!"
else
  printf '\n%s\n\n' "Starting docker..."
  if systemctl start docker &> /dev/null
  then
    printf '\n%s\n\n' "Docker has started."
  else
    printf '\n%s\n\n' \
    "Docker cannot be started." \
    "Run 'systemctl start docker' to see error."
    exit
  fi
fi

#force patience function
wait_for_containers () {
  while ! nc -zv 192.168.6.105 22 -w 1 &> /dev/null
  do 
    printf "."
    sleep 1
    ((i++))
    if [ "$i" -gt 30 ]
    then
      printf '\n%s\n\n' \
      "Apps aren't launching. Something is wrong." \
      "Try restarting the VM, then restart Docker." \
      "Then run the script again." 
      exit
    fi
  done
}

#wut you want
cat << EOF
What do you want to?

1 - Start Apps
2 - Stop Apps
3 - Remove Apps
4 - Exit
EOF

printf "\nEnter a number: "

read -r choice
case $choice in
  1)
    #are the Apps already installed?
    if docker container inspect target-machine &> /dev/null
    then 
      if docker ps | grep target-machine
      then
        printf '\n%s\n\n' \
        "Looks like your apps are already running!"
        exit
      else
        printf '\n%s\n\n' "Starting web apps..." \
        "The web apps may take a few mins to completely start up. Please wait."
        service docker restart
        docker container start target-machine
        wait_for_containers
        printf '\n%s\n\n' \
        "The web apps are running!" \
        "You're ready to start hacking!!!"
        exit
      fi
    else
      # start apps with dir bindings
      printf '\n%s\n\n' "Starting web apps for the first time!"
      service docker restart
      if
        docker network create \
          --driver=bridge target-machine-net --attachable \
          --subnet=192.168.6.0/24 >/dev/null
        docker run --name target-machine \
          -d \
          -p 15552:22 \
          --network=target-machine-net \
          --ip="192.168.6.105" \
          -e "TZ=America/New_York" \
          cyberxsecurity/target-machine >/dev/null
      then
        printf '\n%s\n\n' \
        "Your web apps are installed and running!" \
        "It may take a few mins to completely start up. Please wait."
        wait_for_containers
        printf '\n%s\n\n' "Your web apps are running!" \
        "You're ready to start hacking!!!"
        exit

      else 
        printf '\n%s\n\n' "The 'docker run' command failed." \
        "Check the docker logs with 'docker logs <container-name>'"
        exit
      fi
    fi
    ;;
  2)
    #stop web apps, unless they are already stopped!
    if docker ps | grep target-machine
    then
      printf '\n%s\n\n' "Stopping web apps..."
      docker container stop target-machine
      printf '\n%s\n\n'  "Web apps have been stopped."
      exit
    else
      printf '\n%s\n\n' \
      "Web apps are not running!" \
      "Run the script again and choose another option."
      exit
    fi
    ;;
  3)
    # remove all web app components
    printf '\n%s\n\n'  "Removing web apps..." 
    if docker container inspect target-machine &> /dev/null
    then
      printf '\n%s\n\n' "Stopping and removing containers..." 
      # docker container stop target-machine &> /dev/null
      docker container rm -f target-machine &> /dev/null
      docker network rm target-machine-net &> /dev/null
      # yes | docker network prune &> /dev/null
      printf '\n%s\n\n' "Removing web app container images..." 
      docker image rm cyberxsecurity/target-machine &> /dev/null
      #printf '\n%s\n\n' -y | docker image prune -a &> /dev/null
      printf '\n%s\n\n' "Web app containers and images have been removed."
      exit
    else
      printf '\n%s\n\n' "Looks like web apps are already uninstalled!!"
      exit
    fi
    ;;
  4)
    printf '\n%s\n\n' "Exiting web app script." 
    exit
    ;;
  *)
    printf '\n%s\n\n' "Invalid choice..." \
    "Run the script again and choose another option."
    exit
    ;;
esac
