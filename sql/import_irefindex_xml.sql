begin;

\copy xml_experiments from '<directory>/experiment.txt'
\copy xml_interactors from '<directory>/interactor.txt'
\copy xml_names from '<directory>/names.txt'
\copy xml_xref from '<directory>/xref.txt'
\copy xml_organisms from '<directory>/organisms.txt'

commit;
