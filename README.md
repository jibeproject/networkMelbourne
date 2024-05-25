# networkMelbourne
Code for generating the Melbourne transport network

# instructions

See ```generate_network.sh``` for detailed instructions. As an overview:

Run ```/network/NetworkGenerator_JIBE.R``` to generate the network geometries for Melbourne. Technically it generates a network for all of Victoria so we can make a more accurate freight model. Now adds crossings to the nodes. You'll need the code from the latest dev branch of [MatSIM Melbourne](https://github.com/matsim-melbourne/network/tree/dev)

```clipNetwork.R``` clips the Victoria-wide network to our study region (Greater Melbourne plus a 10km buffer). We do so by finding all edges with an endpoint within the study region, and then finding the largest connected component in order to remove any disconnected components arising from the clip.

```processNetwork.R``` calculates quietness, positive and negative POIs, whether an edge is part of a highstreet, and Shannon diversity. Main difference is the edge snapping takes place in postgres. This has sped up the process from several days to around 30 seconds

```adjustNetwork.R``` performs the final tweaking to ensure the Melbourne network's attributes are compatible with the Manchester network.

```addLTS.R``` adds calculations of Level of Traffic Stress to the network edges, based on a 4-category LTS level that is derived (with some simplification) from a Victorian DTP publication, Victorian Department of Transport 2020, Cycling Level of Traffic Stress Methodology, Melbourne.  The levels are based on cycleway status, highway type, speed limit, and traffic volumes taken from a traffic simulation. The fields added by the function are as follows.

| Field              | Content                                                  |
|--------------------|----------------------------------------------------------|
|aadt                |Total traffic for the link, in both directions if applicable |
|aadtFwd, aadtFwd_car, aadtFwd_truck |Total traffic, car traffic and truck traffic for the link in the forward direction |
|aadtRvs, aadtRvs_car, aadtRvs_truck |For two-way links, equivalent traffic details for the link in the reverse direction |
|LTS_fwd             | Level of Traffic Stress for the link in the forward direction, in 4 levels (1 to 4) |
|LTS_link_imped_fwd  | Impedance attributable to LTS for the link, in metres, in the forward direction |
|LTS_isec_imped_fwd  | Impedance attributable to LTS for the intersection at the end of the link, in metres, in the forward direction |
|LTS_total_imped_fwd | The sum of LTS_link_imped_fwd and LTS_isec_imped_fwd     |
|LTS_rvs, LTS_link_imped_rvs, LTS_isec_imped_rvs, LTS_total_imped_rvs | For two-way links, equivalent LTS details for the link in the reverse direction |




