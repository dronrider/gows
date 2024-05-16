# godeps

The script allows you to simplify working with the dependencies of a specific project. By passing a link to the project, the script will clone it into the working directory, generate a file of internal project dependencies, and clone them in the same way. At the end, it will generate a go.work file so that local development can be carried out.

The list of incoming script arguments can be obtained by running the command:
```bash
./ws.sh -h
```

## Sample usage

To run the script, you first need to grant permissions to the file:
```
chmod +x ./ws.sh
```

Run the script:
```
./ws.sh -u git@gitlab.ru:group/project.git -e ~/work_dir/env.sh -d ~/work_dir
```

The script will create folowing directory tree:
```
~/work_dir/deps/group-project.yaml
~/work_dir/projects/project
~/work_dir/go.work
~/work_dir/go.work.sum
```
