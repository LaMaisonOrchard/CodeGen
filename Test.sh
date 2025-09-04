echo "## UNITTEST ######################################"
dub test
echo "## JSON     ######################################"
dub -- -tmpl test.tmpl test.json -copy other
echo "## PROTO    ######################################"
dub -- -tmpl  testa.tmpl test.proto -copy other
dub -- -super testb.tmpl test.proto test2.proto -copy other