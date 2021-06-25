def read_sequences(file_name: str) -> iter:
    """ Reads an MFP qPCR file and returns an iterable of fasta headers """
    with open(file_name) as fin:
        for line in fin:
            line = line.rstrip()
            if not line.startswith("-"):
                yield line


def get_key(dct, value):
    """ Convenience function to get all keys in Python dictionary that match a value """
    return [key for key in dct if (dct[key] == value)]


def main():
    import sys
    qpcr_file = sys.argv[1]
    # print("Testing...")
    # qpcr_file = "../../../repos/crop_priming/data/prepped.fungene_9.6_amoA_AOB_1205_unaligned_nucleotide_seqs.fa.primers.out"
    array_counter = 0
    seq_count = 0
    header_line = ""
    prefix = "amoA"
    forward_primers = {}
    reverse_primers = {}
    forward_primers_num = 0
    reverse_primers_num = 0
    org_accession_list = []

    for line in read_sequences(qpcr_file):
        with open("test", "w") as fout:
            if line.startswith("F"):
                ## Finish

                # print(f"Total organisms targeted: {seq_count}")
                # print(f"Total uncultured organisms: {uncultured_count}")
                # if seq_count == uncultured_count:
                #     print("All organisms uncultured.")

                for org, acc in org_accession_list:
                    fout.write(f"{header_line}\t{org}\t{acc}\n")



                ## Reset
                # uncultured_count = 0
                org_accession_list = []
                seq_count = 0
                array_counter += 1

                array_name = f"{prefix}.{array_counter:03}"

                original_forward_name, forward_seq, original_reverse_name, reverse_seq, _ = line.split()

                ## Have we seen this original_forward_name before? If not, add it in to the forward primer dict.
                ## Else, use the name that we found before.
                if original_forward_name not in forward_primers.values():
                    forward_primers_num += 1
                    # forward_primers.append(forward_seq)

                    forward_primer_name = f"{prefix}.{forward_primers_num:03}F"

                    forward_primers[forward_primer_name] = original_forward_name
                else:
                    forward_primer_name = get_key(forward_primers, original_forward_name)[0]

                ## Repeat for reverse primers.
                if original_reverse_name not in reverse_primers.values():
                    reverse_primers_num += 1
                    # reverse_primers.append(reverse_seq)
                    reverse_primer_name = f"{prefix}.{reverse_primers_num:03}R"

                    reverse_primers[reverse_primer_name] = original_reverse_name
                else:
                    reverse_primer_name = get_key(reverse_primers, original_reverse_name)[0]

                header_line = "{}\t{}\t{}\t{}\t{}\t{}\t{}".format(
                    array_name,
                    forward_primer_name,
                    original_forward_name,
                    forward_seq,
                    reverse_primer_name,
                    original_reverse_name,
                    reverse_seq,
                )

            else:
                seq_count += 1
                line = line.split(",")
                accession, organism, definition = line
                accession = accession[1:accession.find("_")]
                organism = organism[organism.find("=") + 1:]
                definition = organism[organism.find("=") + 1:]

                if (organism, accession) not in org_accession_list:
                    org_accession_list.append((organism, accession))

                # if "uncultured" in organism:
                    # print("\t----Found uncultured---")
                    # uncultured_count += 1

                # print(f"{header_line}\t{organism}\t{accession}")

        # print(f"Primer dict length: {len(forward_primers)}")
        # print(f"Number of forward primers: {forward_primers_num}")

        # print("\n".join("{}\t{}".format(k, v) for k, v in forward_primers.items()))


        # print(f"Primer dict length: {len(reverse_primers)}")
        # print(f"Number of reverse primers: {reverse_primers_num}")
        for org, acc in org_accession_list:
            print(f"{header_line}\t{org}\t{acc}")

if __name__ == '__main__':
    main()
