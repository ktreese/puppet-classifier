# puppet-classifier
Ruby Classification Script

###### This is my first ruby script

 ![WARNING](http://kristianreese.com/images/warning.png "WARNING")
 This script will delete the 'Agent-specified environment' and 'Production environment' Node Groups because I do not use them.  If you do, then remove lines 83 thru 93

Here is how I go about using [puppet-classify](https://github.com/puppetlabs/puppet-classify) and the [Ruby MongoDB Driver](https://docs.mongodb.org/ecosystem/drivers/ruby/) to backup my puppet classifications into MongoDB.

In it, I have two MongoDB databases.  One for my local vagrant development environment, and the other for production.

```
Usage: opts.rb [options]
    -i, --import                     import classifications from mongoDB
    -e, --export                     export classifications to mongoDB
    -f, --file FILENAME              export peconsole classifications to FILENAME (provide full path and filename -> /tmp/classifications.json for example)
    -d, --display DISPLAY            Select which repository to display classifications (puppet, mongo, difference)
    -u, --update-classes             Update/Sync classes
    -h, --help                       Show this message
```


[Ruby MongoDB Driver Tutorial](https://docs.mongodb.org/ecosystem/tutorial/ruby-driver-tutorial/)
