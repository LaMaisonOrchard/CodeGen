echo "## UNITTEST ######################################"
dub test
echo "## PROTO    ######################################"
dub -- -tmpl  ExampleA.tmpl Example.proto -copy other
dub -- -super ExampleB.tmpl Example.proto -copy other