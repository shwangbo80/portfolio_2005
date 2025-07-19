const navContainer = document.querySelector(".nav-container");

navContainer.innerHTML = `<nav class="navbar navbar-expand-lg navbar-light bg-light">
            <div class="container-fluid">
                <a class="navbar-brand" href="index.html">
                    <img src="assets/images/logo2.png" alt="" width="250">
                </a>
                <button class="navbar-toggler" type="button" data-bs-toggle="collapse"
                        data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent"
                        aria-expanded="false" aria-label="Togx\`gle navigation">
                    <span class="navbar-toggler-icon"></span>
                </button>
                   <div class="collapse navbar-collapse" id="navbarSupportedContent">
                    <div class="me-auto"></div>
                    <form class="d-flex">
                        <ul class="navbar-nav mb-2 mb-lg-0">
                            <li class="nav-item">
                                <a class="nav-link" aria-current="page" href="about.html">ABOUT</a>
                            </li>
                            <li class="nav-item dropdown">
                                <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button"
                                   data-bs-toggle="dropdown" aria-expanded="false">
                                    SERVICES
                                </a>
                                <ul class="dropdown-menu" aria-labelledby="navbarDropdown">
                                    <li><a class="dropdown-item"
                                           href="abstraction-and-due-diligence.html">Abstraction & Due
                                        Diligence</a></li>
                                    <li><a class="dropdown-item" href="business-process-review.html">Business
                                        Process Reviewn</a></li>
                                    <li><a class="dropdown-item" href="corporate-training.html">Corporate
                                        Training</a></li>
                                    <li><a class="dropdown-item" href="database-management.html">Database
                                        Management</a></li>
                                    <li><a class="dropdown-item" href="desk-and-field-audits.html">Desk & Field
                                        Audits</a></li>
                                    <li><a class="dropdown-item" href="diversity-programs.html">Diversity
                                        Programs</a></li>
                                    <li><a class="dropdown-item"
                                           href="implementation-transition.html">Implementation / Transition</a>
                                    </li>
                                    <li><a class="dropdown-item" href="project-management.html">Project
                                        Management</a></li>
                                    <li><a class="dropdown-item" href="quality-control.html">Quality Control</a>
                                    </li>
                                    <li><a class="dropdown-item" href="technology-selection.html">Technology
                                        Selection</a></li>
                                </ul>
                            </li>
                            <li class="nav-item dropdown">
                                <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button"
                                   data-bs-toggle="dropdown" aria-expanded="false">
                                    COMPANY PROFILE
                                </a>
                                <ul class="dropdown-menu" aria-labelledby="navbarDropdown">
                                    <li><a class="dropdown-item" href="history.html">History</a></li>
                                    <li><a class="dropdown-item" href="mission.html">Mission</a></li>
                                    <li><a class="dropdown-item" href="ann-cho.html">Magement Team</a>
                                    </li>
                                </ul>
                            <li class="nav-item">
                                <a class="nav-link" aria-current="page" href="contact.html">CONTACT</a>
                            </li>
                            </li>
                        </ul>
                    </form>
                </div>
            </div>
        </nav>`;

