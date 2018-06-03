#!/bin/bash

current=$(pwd)

cd charts

helm package ../
helm repo index ./

cd $current