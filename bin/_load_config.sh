config_file="bin/.env";

if [[ -s $config_file ]];
then
    echo -e "\033[33;32mLoading ENV config from $config_file\033[0m";
    source $config_file;
else
    echo -e "\033[0;31m
Can't find any configuration in $config_file, the library won't work properly.
To work locally, you should create the file and use bin/.env.example as a model.
\033[0m";
exit 1;
fi
