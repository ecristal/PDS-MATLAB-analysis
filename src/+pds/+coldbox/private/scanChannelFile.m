function file = scanChannelFile(folder,channel)
%SCANCHANNELFILE Locate the compressed or raw DAPHNE file for a channel.
stem = fullfile(folder,sprintf('channel_%d',channel));
file = stem + ".7z";
if ~isfile(file)
    file = stem + ".dat";
end
assert(isfile(file),'No .7z or .dat file for channel %d in %s.',channel,folder);
end
