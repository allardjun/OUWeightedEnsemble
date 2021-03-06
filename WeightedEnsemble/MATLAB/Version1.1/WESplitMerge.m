function [newX, newWeights] = WESplitMerge(x, weights,paramsWE) 
%Basic shell for weighted ensemble functionality
%Assumes that the data is in the current kernel, obviously will need to load data when adapting to C
%Things that will necessarily change in the next iteration
%1. Data location / access / storage
%2. Bin definitions
%x is the variable that will store the data

 %Specify how many bins exactly that is
 
 %% Below loads/sorts input + into bins
repPerBin = paramsWE.repsPerBin;
fluxBin = paramsWE.fluxBin;
binParams = paramsWE.binDefs;
binIDs = findBin(x,binParams); %Gives the identity of each bin 
usedBins = unique(binIDs).';
nBins = numel(unique(binIDs));


% move preallocation out of WE loop
newWeights = NaN((nBins+1) * repPerBin, 1); %Preallocate vectors with enough room for copies
newWeights(1:length(weights)) = weights;
newX = NaN((nBins+1) * repPerBin, 1,'double');
newX(1:length(x)) = x;
newIDs = NaN((nBins+1) * repPerBin, 1);
newIDs(1:length(x)) = binIDs;

%% Below is the Merging loop

for n = usedBins
    xInBin = newIDs == n; %Boolean true / false for whether a specific point in the x vector is in the bin
    nInBin = numel(newX(newIDs == n)); %For each bin, find the number of reps in the bin
    
%The result of this allows us to create a reduced vector with only the x components
%in the bin through newX(xInBin).

%In the following comments: "reduced vector" refers to the vector
%newX(xInBin). Extended vector refers to the vector newX.
    
%Below through the following process for each bin. 
%Firstly, checks to make sure that there are replicas in the bin
%Second, while there are more replicas in the bin than necessary, we check
%to see how many replicas inside the bin share the smallest weight. If it's more than one,
%we combine the first two listed in the vector together. Otherwise, we
%combine the smallest with the first found second smallest.
    if nInBin>0 && nInBin > repPerBin 
        while nInBin > repPerBin
            if length(find(newWeights(xInBin)== min(newWeights(xInBin)))) > 1
                mergeNumber = find(newWeights(xInBin) == min(newWeights(xInBin)),2,'first');
                %mergeNumber: Gives the index of the replicas to be combined in the REDUCED vector
                mergeIndex = find(xInBin);
                %Gives the indices inside the extended vector of all of the
                %reduced vector components. E.g. if element 1,5,10 of
                %extended vector are inside the reduced vector, mergeIndex
                %becomes the vector [1,5,10]
                mergeIndex = mergeIndex(mergeNumber);
                %Gives the indices of the replicas to be combined inside
                %the extended vector
            else
                %The following is a similar process, but specifies a
                %"second smallest" weight for when there's only one
                %smallest
                mergeNum1 = find(newWeights(xInBin) == min(newWeights(xInBin)),1,'first');
                mergeNum2 = find(newWeights(xInBin) == min(setdiff(newWeights(xInBin),min(newWeights(xInBin)))),1,'first');
                mergeIndex = find(xInBin);
                mergeIndex = mergeIndex([mergeNum1,mergeNum2]);
            end
            %Now that we know the locations of the replicas to be combined
            %in the overall vector, we combine their weights and replace
            %the extras with NaNs.
            mergeProb = newWeights(mergeIndex(1))/(newWeights(mergeIndex(1)) + newWeights(mergeIndex(2)));
            keptIndex = 1+(rand < mergeProb);
            lostIndex = 3 - keptIndex;
            newWeights(mergeIndex(keptIndex)) = sum(newWeights(mergeIndex));
            newWeights(mergeIndex(lostIndex)) = NaN;
            newX(mergeIndex(lostIndex)) = NaN;
            newIDs(mergeIndex(lostIndex)) = NaN;
            %Following 2 lines updates the counts for number of entries in
            %the bin and the boolean true false that helps us locate
            %replicas
            xInBin = newIDs == n;
            nInBin = numel(newX(newIDs == n));
        end
    end
end


%% Below is the splitting loop

for n = usedBins
    xInBin = newIDs == n;
    nInBin = numel(newX(newIDs == n)); 
    if nInBin>0 && nInBin > repPerBin 
    else if nInBin > 0 && nInBin < repPerBin
            count = 0;
        while nInBin < repPerBin
            count = count+1;
            splitNumber = find(newWeights(xInBin) == max(newWeights(xInBin)),1,'first');
            splitIndex = find(xInBin);
            splitIndex = splitIndex(splitNumber);
            newWeights(splitIndex(1)) = newWeights(splitIndex(1))/2;
            newWeights(find(isnan(newWeights),1,'first')) = newWeights(splitIndex);
            newX(find(isnan(newX),1,'first')) = newX(splitIndex);
            newIDs(find(isnan(newX),1,'first')) = n;
            xInBin = newIDs == n;
            nInBin = numel(newX(newIDs == n));
            if count > repPerBin
                fprintf('Infinite Loop? \n')
                break
            end
        end
    end
    end
end

%% Below cleans the final output
%Remove all NaN entries from the output
    filledIndex = ~isnan(newX);
    newX = newX(filledIndex);
    newWeights = newWeights(filledIndex);
end
        