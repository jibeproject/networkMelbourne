# networkMelbourne
Code for generating the Melbourne transport network

# instructions

See ```generate_network.sh``` for detailed instructions. As an overview:

Run ```/network/NetworkGenerator_JIBE.R``` to generate the network geometries for Melbourne. Technically it generates a network for all of Victoria so we can make a more accurate freight model. Now adds crossings to the nodes. You'll need the code from the latest dev branch of [MatSIM Melbourne](https://github.com/matsim-melbourne/network/tree/dev)

```clipNetwork.R``` clips the Victoria-wide network to our study region (Greater Melbourne plus a 10km buffer). We do so by finding all edges with an endpoint within the study region, and then finding the largest connected component in order to remove any disconnected components arising from the clip.

```processNetwork.R``` calculates quietness, positive and negative POIs, whether an edge is part of a highstreet, and Shannon diversity. Main difference is the edge snapping takes place in postgres. This has sped up the process from several days to around 30 seconds

```adjustNetwork.R``` performs the final tweaking to ensure the Melbourne network's attributes are compatible with the Manchester network.

