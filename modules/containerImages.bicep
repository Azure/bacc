param images array = []
param acrLoginServer string = ''

output containerImageNames array = map(images, item => replace(item, '\${acr}', acrLoginServer))
